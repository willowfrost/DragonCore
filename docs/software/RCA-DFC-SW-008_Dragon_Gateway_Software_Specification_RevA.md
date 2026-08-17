**DRAGON GATEWAY™ SOFTWARE SPECIFICATION**

Document Number: RCA-DFC-SW-008  
Revision: A  
Status: Technical Baseline  
Product: Dragon Core™ Revision A  
Program: Dragon Flight™ Core ASIC Development Program  
Organization: Royal Cubit Aerospace

# Revision History

| Revision | Date | Description | Author |
|---|---|---|---|
| A | 2026-08-07 | Initial Dragon Gateway software baseline derived beneath the eight controlling Dragon Flight specifications | Royal Cubit Aerospace |

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
5. Dragon Gateway Configuration Item Identification
6. Authority, Ownership, and Product Boundary
7. External Integration Roles and Deployment Profiles
8. Execution and Deployment Environment
9. Software Architecture
10. Process, Thread, and Scheduling Model
11. Device-Service, Gateway, and Client Session Model
12. Northbound Integration Interface
13. Southbound Dragon Service Interface
14. Startup, Discovery, and Compatibility
15. Gateway Operating-State Model
16. Authentication, Authorization, and Policy Enforcement
17. Command Admission and Validation
18. Typed Functional Service Exposure
19. Observation, Event, and Diagnostic Publication
20. Configuration and State-Changing Workflows
21. Command Result and Completion Model
22. Idempotency, Deduplication, and Replay Control
23. Ambiguous-Outcome Reconciliation
24. Disconnect, Restart, and Recovery
25. Subscription, Queue, and Backpressure Management
26. Data Transformation and Representation
27. Persistence and Data Custody
28. Logging, Audit, and Evidence Export
29. Security and Trust Boundaries
30. Availability, Isolation, and Failover
31. Concurrency and Resource Management
32. Timing, Rate, and Performance
33. Error Handling and Degraded Operation
34. Human Administration and Automation Interfaces
35. Portability and Platform Adaptation
36. Internal and External Software Interfaces
37. Protocol, Schema, and Compatibility Versioning
38. Software Verification and Validation
39. Traceability and Change Control
40. Build, Package, Deployment, and Release
41. Deliverables
42. Exit Criteria
43. Baseline Statement

# 1. Purpose

This specification defines Dragon Gateway, an external-host integration service that connects authorized external systems to Dragon Core services. Dragon Gateway translates validated external requests into typed Dragon SDK operations and publishes typed observations, results, events, and diagnostics without exposing the Dragon Core register map as an unrestricted remote protocol.

Dragon Gateway executes entirely outside the fabricated Dragon Core device. It normally communicates with a privileged local Dragon device service through authenticated, typed software interfaces. In a compact embedded deployment it may be linked into the same executable as that service, provided that the same ownership, serialization, authorization, lifecycle, recovery, and audit boundaries remain enforceable.

This specification owns Dragon Gateway software behavior, composition, northbound integration semantics, schema use, session management, authorization enforcement, command admission, publication, persistence, security, recovery, deployment, verification, and release requirements. It does not own or redefine product scope, device behavior, internal hardware architecture, register meaning, SPI behavior, controlling verification cases, controlling trace relationships, RTL rules, physical interfaces, aircraft application policy, or external-system behavior.

`DGS-PUR-001` — Dragon Gateway shall provide controlled protocol translation between authorized external systems and public Dragon SDK or device-service operations.

`DGS-PUR-002` — Dragon Gateway shall preserve every safety, access, compatibility, atomicity, side-effect, evidence, result, and recovery distinction supplied by the typed Dragon software stack.

`DGS-PUR-003` — Dragon Gateway shall not create a remote register-access tunnel, a substitute device definition, or a software bypass around hardware-owned controls.

# 2. Scope

## 2.1 Included Scope

This specification covers:

- the Dragon Gateway executable and supporting libraries;
- network-facing and local external-system protocol adapters;
- canonical gateway commands, results, observations, notifications, and error envelopes;
- external-client authentication, authorization, tenancy, sessions, quotas, and rate limits;
- schema, protocol-profile, and compatibility management;
- command admission, validation, policy enforcement, dispatch, completion, and audit;
- typed access to discovery, lifecycle, configuration, observation, interrupt, event, diagnostic, databus, monitoring, routing, fault, safety-status, reset, and recovery services;
- idempotency, deduplication, replay control, deadline handling, and ambiguous-outcome reconciliation;
- subscription, publication, queueing, backpressure, retention, and loss evidence;
- separation of active conditions, sticky evidence, current values, cached values, derived values, and stale values;
- process isolation, security, availability, recovery, persistence, logging, audit, verification, build, packaging, deployment, release, and maintenance obligations; and
- compact embedded, hosted-service, redundant-service, laboratory, and production-safe deployment profiles.

## 2.2 Excluded Scope

The following are excluded:

- any executable software, processor, bootloader, runtime, memory, gateway, network stack, key store, or application inside Dragon Core;
- direct SPI-master implementation by Dragon Gateway application code;
- redefinition of a register, field, access class, device state, device timing rule, queue behavior, event meaning, fault meaning, command side effect, or verification outcome;
- unrestricted remote raw-register, arbitrary-memory, scan, production-test, fault-injection, RTL-hierarchical, platform-private, or shared-buffer access;
- aircraft flight control, navigation, guidance, mission management, vehicle-control decisions, or direct aircraft-energy control;
- ownership of external-system business logic, aircraft application policy, installation authorization, or external endpoint correctness;
- physical network media, routers, firewalls, switches, cabling, radio links, certificate-authority operation, enterprise identity-provider operation, or site cybersecurity accreditation;
- external ARINC 429, CAN, UART, sensor, actuator, analog, transceiver, power, or aircraft wiring design; and
- aircraft certification, installation approval, operational authorization, or aircraft-level safety assessment.

## 2.3 Intended Use

Dragon Gateway is intended for controlled machine-to-machine integration. It may serve embedded controllers, laboratory automation, maintenance systems, ground-support equipment, test systems, operational data consumers, and installation-specific applications. It is not itself a flight-control application and shall not be credited with a safety responsibility assigned to Dragon Core hardware.

`DGS-SCOPE-001` — Every Dragon Core operation requested through Dragon Gateway shall use a public typed service governed by `RCA-DFC-SW-001` and `RCA-DFC-SW-003`.

`DGS-SCOPE-002` — Dragon Gateway shall not depend on a platform-private register, undocumented opcode, RTL hierarchy, physical shared-buffer address, scan path, testbench backdoor, or hidden device state.

`DGS-SCOPE-003` — Dragon Gateway shall remain removable or disconnectable without preventing Dragon Core hardware from performing configured autonomous supervision.

`DGS-SCOPE-004` — A deployment shall not expose a capability merely because the underlying SDK can perform it; exposure requires an explicit Gateway schema, policy, authorization, and verification allocation.

`DGS-SCOPE-005` — Gateway or external-client disconnection shall not interrupt local device supervision, evidence retrieval, or configured watchdog scheduling.

# 3. Applicable Documents

## 3.1 Controlling Technical Specifications

The canonical order and sole normative ownership of the controlling set are defined only by `RCA-DFC-CHTR-002`, Section 3.1. The following table is an informative Gateway-use view and creates no alternate precedence.

| Document | Dragon Gateway use |
|---|---|
| `RCA-DFC-CHTR-002.md` | Product mission, exclusions, external-host model, fixed constraints, and single-owner rules |
| `RCA-DFC-PBIO-002.md` | Device, software, host, data, security, safety, interface, and verification responsibility allocation |
| `RCA-DFC-SRS-002.md` | Externally observable device behavior and logical host-interface obligations consumed through typed services |
| `RCA-DFC-ARCH-002.md` | Device-side contracts needed to interpret lifecycle, coherent access, events, queues, diagnostics, reset, and reconciliation |
| `RCA-DFC-REG-002.md` | Sole normative source for host-visible registers, fields, access, legality, protection, behavior, and side effects |
| `RCA-DFC-VP-002.md` | Sole normative source for device and host-boundary verification methods, cases, outcomes, and evidence definitions |
| `RCA-DFC-RTM-002.md` | Sole normative source for relationships among controlling technical identifiers |
| `RCA-DFC-RTL-STD-002.md` | RTL implementation and structural rules; not a Dragon Gateway software standard |

## 3.2 Governing Software Specifications

| Document | Governing relationship |
|---|---|
| `RCA-DFC-SW-001`, Revision C | External-host software architecture and Dragon Gateway architectural allocation |
| `RCA-DFC-SW-002`, Revision B | External embedded-host firmware services used in compact embedded deployments |
| `RCA-DFC-SW-003`, Revision B | Public HAL, BSP, driver, typed API, lifecycle, result, and recovery contracts |
| `RCA-DFC-SW-004`, Revision B | Software coding and implementation standard |
| `RCA-DFC-SW-005`, Revision B | Software verification and validation requirements |
| `RCA-DFC-SW-006`, Revision B | Build, package, deployment, release, manifest, integrity, and archival requirements |
| `RCA-DFC-SW-007`, Revision A | Console interaction and engineering workflow peer; it does not own Gateway behavior |

## 3.3 Historical Reference

No historical Dragon Gateway specification was supplied or used. This Revision A specification is newly derived from the controlling technical specifications and the governing software baseline.

## 3.4 Authority and Single-Definition Rules

`DGS-DOC-001` — Dragon Gateway shall apply `CHTR-DOC-001` through `CHTR-DOC-007`.

`DGS-DOC-002` — A device fact shall be consumed from its controlling owner or generated typed binding and shall not be copied into Gateway code, schemas, policy files, or documentation as an alternate definition.

`DGS-DOC-003` — A northbound schema may name and constrain a Gateway operation but shall not independently define a Dragon Core register, encoding, capacity, timing constant, or side effect.

`DGS-DOC-004` — Generated bindings and schema artifacts shall retain their source identity and shall not become alternate controlling specifications.

`DGS-DOC-005` — If implementation or verification exposes a conflict, ambiguity, omission, unreachable behavior, or unimplementable contract, dependent work shall stop and the owning specification shall be corrected before Dragon Gateway invents a substitute.

## 3.5 Controlling-Specification Change Flags

No change to a controlling specification is required to establish this Revision A baseline.

The controlling specifications intentionally allocate external authentication, authorization, network security, application policy, persistence, and protocol translation to external software and system owners. This specification defines the Dragon Gateway software allocation within that boundary. Deployment-specific network protocol bindings, identity-provider integration, trust anchors, endpoint addresses, certificates, and external-system policies remain controlled deployment inputs and do not require changes to the Dragon Core technical specification set.

# 4. Definitions, Acronyms, and Abbreviations

| Term | Definition in this specification |
|---|---|
| Active configuration | Device-active value reported through typed active readback; distinct from a requested, desired, or staged value. |
| Ambiguous outcome | A state-changing operation for which a definitive device result was not validated and software therefore cannot safely infer whether an effect occurred. |
| Canonical Gateway model | Protocol-neutral typed command, result, observation, notification, identity, and error representation owned by this specification. |
| Client | An authenticated external software principal or system using a Dragon Gateway interface. |
| Command admission | Ordered validation and policy evaluation completed before a request may reach a typed Dragon service. |
| Definitive result | A validated terminal result establishing success or an applicable failure class for the requested operation. |
| Desired configuration | Externally persisted configuration intended for application; it is not active until applicable device readback proves activation. |
| Device context | One isolated software lifecycle and service context for one physical Dragon Core instance. |
| Device service | Privileged external-host software that owns physical-device access, lifecycle, serialization, service scheduling, diagnostics, and recovery. |
| Gateway | Dragon Gateway executable and its controlled supporting components. |
| Idempotency key | Client-supplied identifier used to correlate and deduplicate a Gateway request within a declared scope and retention interval. |
| Northbound interface | Gateway interface presented to authorized external clients. |
| Observation | Typed state or evidence obtained from a Dragon service, including provenance, freshness, and semantic class. |
| Policy decision | Explicit allow, deny, or constrained-allow result produced from authenticated identity, authorization data, operation, target, state, and deployment policy. |
| Protocol profile | Versioned binding of the canonical Gateway model to a selected external transport, encoding, security mode, limits, and endpoint set. |
| Replay | Reuse of a prior authenticated request or security message outside its permitted freshness and uniqueness rules. |
| Southbound interface | Authenticated typed software interface from Gateway to the Dragon device service or in-process equivalent. |
| Sticky evidence | Device-retained historical indication defined by a controlling specification; distinct from Gateway logs and notifications. |
| Tenant | An isolated administrative scope containing clients, credentials, policy, quotas, subscriptions, and audit ownership. |
| TTL | Time to live. |

Device-side terminology, units, identifiers, encodings, access classes, capacities, and timing retain the definitions of their controlling owners.

# 5. Dragon Gateway Configuration Item Identification

## 5.1 Software Configuration Items

| Configuration item | Purpose | Execution or storage location |
|---|---|---|
| `dragon_gateway` | Main Gateway service, lifecycle coordination, command admission, publication, and administration | Approved external host |
| `dragon_gateway_core` | Protocol-neutral canonical models, policy hooks, request state machine, and result handling | Linked library or service component |
| `dragon_gateway_northbound` | External protocol-adapter framework and approved protocol profiles | Gateway process or isolated adapter process |
| `dragon_gateway_southbound` | Authenticated client for public device-service and Dragon SDK operations | Gateway process |
| `dragon_gateway_policy` | Policy schema, evaluator integration, role/capability mapping, and deployment policy loader | Gateway host and controlled policy store |
| `dragon_gateway_publication` | Observation normalization, subscription, queue, backpressure, and delivery components | Gateway process |
| `dragon_gateway_persistence` | Idempotency, audit, configuration, subscription, and durable-delivery records | Approved external storage |
| `dragon_gateway_admin` | Local least-privilege administration and health interface | Gateway host |
| `dragon_gateway_schema` | Canonical schemas, compatibility metadata, validators, and generated protocol artifacts | Build outputs and deployment package |
| `dragon_gateway_tests` | Unit, component, integration, security, fault-injection, performance, and acceptance tests | Verification environments |

## 5.2 Identification Requirements

`DGS-CI-001` — Every executable and library shall identify its semantic version, source revision, build identifier, build profile, target platform, toolchain, dependency manifest, governing software revisions, and controlling-specification revisions.

`DGS-CI-002` — Each Gateway execution record shall identify the Gateway release, protocol-profile version, schema version, policy version, Dragon SDK release, generated-binding identity, device-service release, deployment identity, and discovered device identity as independent values.

`DGS-CI-003` — A filename, endpoint name, build date, product label, or version string alone shall not establish compatibility.

`DGS-CI-004` — Development, test, engineering, maintenance, and production-safe packages and profiles shall have distinct machine-readable identities.

# 6. Authority, Ownership, and Product Boundary

## 6.1 Responsibility Allocation

| Subject | Dragon Gateway owns | Dragon Gateway shall not own |
|---|---|---|
| External integration | Protocol translation, schema validation, sessions, delivery | External-client correctness or device protocol definition |
| Identity and access | Authentication integration, authorization enforcement, tenant isolation, audit | Enterprise identity-provider operation or Dragon Core hardware protection behavior |
| Commands | Admission, typed dispatch, correlation, result publication | Register legality, device side effects, or terminal device-result encoding |
| Observations | Subscription, normalization, freshness, delivery, external retention | Generation or semantic definition of device evidence |
| Configuration | External desired values, policy, authorized workflows, readback comparison | Register-field meaning, hardware validation, or activation behavior |
| Persistence | Gateway audit, idempotency, subscription, delivery, and retained observation records | On-device retention or hardware evidence behavior |
| Availability | Gateway restart, isolation, bounded failover, external delivery | Transfer of hardware safety responsibility from Dragon Core |
| Security | External trust boundary, credential use, network protection, software isolation | On-device secure boot, secret storage, cryptographic identity, or aircraft-site accreditation |

## 6.2 Boundary Requirements

`DGS-BND-001` — Gateway application components shall not call platform SPI primitives or hand-construct register transactions.

`DGS-BND-002` — Only the privileged device service or an equivalently isolated in-process service shall own the Dragon Core physical-device handle and command serializer.

`DGS-BND-003` — A Gateway protocol adapter shall depend on canonical Gateway operations and shall not depend directly on generated register definitions.

`DGS-BND-004` — Gateway-derived interpretation shall be labeled as derived and shall retain a link to the source observation, policy, conversion rule, and software version.

`DGS-BND-005` — Gateway termination, network partition, client failure, or storage failure shall not be represented as changing Dragon Core hardware responsibilities.

# 7. External Integration Roles and Deployment Profiles

## 7.1 External Roles

| Role | Permitted responsibility |
|---|---|
| Gateway administrator | Install, configure, authorize, observe health, manage protocol profiles, and retrieve audit evidence |
| Read-only observer | Retrieve permitted identity, health, status, and evidence without causing device side effects |
| Configuration client | Request explicitly authorized desired-configuration validation and application workflows |
| Operations client | Request a bounded set of installation-approved typed operations |
| Evidence consumer | Subscribe to or retrieve permitted events, diagnostics, results, and audit-linked records |
| Maintenance client | Perform approved maintenance actions under a distinct policy and deployment profile |
| Automation client | Execute machine-authorized workflows using declared credentials, scopes, deadlines, and idempotency keys |

## 7.2 Deployment Profiles

| Profile | Required characteristics |
|---|---|
| Compact embedded | Gateway and device service may share one executable; logical privilege, serialization, policy, and audit boundaries remain intact |
| Hosted service | Gateway uses an authenticated local device-service interface; external adapters are isolated from physical-device permissions |
| Redundant service | One active southbound owner per device; standby instances do not issue device commands until controlled ownership transfer |
| Laboratory | May enable additional typed diagnostic services; raw or test capabilities remain separately gated and nonproduction |
| Production-safe | Exposes only installation-approved schemas and operations; engineering, injection, test, and unrestricted access are absent |

## 7.3 Role and Profile Requirements

`DGS-ROLE-001` — Authorization shall be based on authenticated principal, tenant, deployment profile, operation, target device, parameter constraints, and current policy state.

`DGS-ROLE-002` — Administrative access shall be separated from ordinary command and observation access.

`DGS-ROLE-003` — Production-safe builds shall omit or make cryptographically and operationally inaccessible every engineering-only endpoint.

`DGS-ROLE-004` — No role shall be authorized by display name, network location, process name, or claimed client type alone.

# 8. Execution and Deployment Environment

## 8.1 Required Platform Services

The deployment platform shall provide process or task isolation appropriate to the profile, monotonic time, wall-clock time when required for audit, secure random values, synchronization, bounded memory, authenticated local communication, protected credential access, durable storage when enabled, health supervision, and one or more approved northbound transports.

## 8.2 Deployment Requirements

`DGS-DEP-001` — Platform-specific code shall remain behind approved adapters and shall not alter canonical operation semantics.

`DGS-DEP-002` — Production device access permissions shall be unavailable to northbound adapter processes and external client identities.

`DGS-DEP-003` — Secrets shall be obtained through the approved platform credential mechanism and shall not be compiled into executables, stored in schemas, written to logs, or exposed through diagnostics.

`DGS-DEP-004` — Each deployment shall identify enabled endpoints, transport protection, credential sources, trust anchors, policy source, storage location, resource limits, device targets, and operational ownership.

`DGS-DEP-005` — A deployment lacking a required time, credential, storage, or device-service dependency shall fail closed for affected state-changing operations and report an explicit degraded state.

# 9. Software Architecture

## 9.1 Logical Components

| Component | Responsibility |
|---|---|
| Protocol adapter | Transport framing, peer establishment, canonical-message conversion, response delivery |
| Session manager | Authenticated client context, tenancy, expiry, cancellation, and connection lifecycle |
| Command admission pipeline | Schema, compatibility, authorization, rate, deadline, policy, and state validation |
| Request coordinator | Correlation, idempotency, dispatch, completion, ambiguity, and cancellation state |
| Southbound service client | Typed device discovery, lifecycle, command, observation, and recovery access |
| Publication service | Subscription evaluation, observation typing, queueing, backpressure, and delivery |
| Policy service | Versioned policy decisions and decision evidence |
| Persistence service | Durable idempotency, audit, subscription, configuration, and optional delivery records |
| Health service | Internal readiness, dependency status, metrics, and administrative diagnostics |
| Audit service | Tamper-evident or integrity-protected security, command, policy, and administration records |

## 9.2 Dependency Rules

`DGS-ARCH-001` — Northbound adapters shall depend on the canonical Gateway service interface, not on the Dragon SDK, driver, generated registers, or SPI HAL.

`DGS-ARCH-002` — The request coordinator shall be the sole Gateway owner of a request's state transition from admission through terminal publication.

`DGS-ARCH-003` — The publication service shall not issue state-changing device operations.

`DGS-ARCH-004` — Policy evaluation, audit creation, and request correlation shall be complete before a state-changing operation is dispatched.

`DGS-ARCH-005` — Optional analytics, formatting, or bulk export shall not block command reconciliation, time-critical device service, or audit persistence.

## 9.3 Failure Containment

`DGS-ARCH-006` — A malformed client message shall be contained within its adapter and session and shall not corrupt another client, tenant, device context, or request.

`DGS-ARCH-007` — Failure of one external adapter shall not release device ownership, bypass authorization, or invalidate another adapter's completed audit records.

`DGS-ARCH-008` — An internal invariant violation shall quarantine the affected request or context, preserve available evidence, and require controlled recovery before further state-changing use.

# 10. Process, Thread, and Scheduling Model

## 10.1 Execution Model

Dragon Gateway may use processes, threads, tasks, or an event loop. The implementation shall preserve logical isolation among endpoint reception, authentication, admission, dispatch, publication, persistence, administration, and health supervision.

## 10.2 Scheduling Requirements

`DGS-SCHED-001` — Blocking external I/O shall not execute while holding the device-service serializer, request-state lock, policy lock, or global subscription lock.

`DGS-SCHED-002` — Reconciliation, terminal-result persistence, security audit, and dependency-health work shall have bounded priority over bulk observation publication and export.

`DGS-SCHED-003` — Client cancellation shall stop undelivered client work but shall not cancel, duplicate, or conceal a device operation whose acceptance is possible.

`DGS-SCHED-004` — Every worker, queue, timer, and retry loop shall have a bounded lifetime, capacity, deadline, or controlled shutdown rule.

`DGS-SCHED-005` — Shutdown shall stop new admissions, settle or reconcile accepted work, persist required records, terminate subscriptions, and close southbound access in a defined order.

# 11. Device-Service, Gateway, and Client Session Model

## 11.1 Session Classes

| Session | Identity and ownership |
|---|---|
| Device-service session | One authenticated southbound association to one isolated device context |
| Gateway instance session | One process lifetime and recovery epoch with unique instance identity |
| Client session | One authenticated external principal context with tenant, scopes, expiry, and policy version |
| Request session | One immutable admitted request identity from receipt through final outcome |
| Subscription session | One bounded publication contract with filters, delivery policy, and cursor state |

## 11.2 Session Requirements

`DGS-SESS-001` — A device context shall be identified by discovered device identity and deployment mapping, not by a mutable network endpoint or display label alone.

`DGS-SESS-002` — Reauthentication, privilege change, policy change, or tenant change shall create a new authorization epoch; prior authorization shall not silently carry forward.

`DGS-SESS-003` — Every admitted request shall retain the client identity, tenant, session, request identifier, idempotency scope, target device, operation, schema version, policy version, receipt time, deadline, and audit correlation.

`DGS-SESS-004` — Session expiry shall prevent new operations but shall not erase or falsify the result of an already accepted request.

`DGS-SESS-005` — Device-service reconnect shall trigger compatibility and state recovery before state-changing Gateway admissions resume.

# 12. Northbound Integration Interface

## 12.1 Canonical Operation Classes

The protocol-neutral northbound model shall support:

- service identity and capability discovery;
- device identity, compatibility, and lifecycle observation;
- read-only typed observation requests;
- bounded subscriptions and cursor-based retrieval;
- authorized typed state-changing commands;
- command-status and final-result retrieval;
- desired-configuration validation and controlled application;
- evidence and diagnostic retrieval;
- health and administrative observation through a separate interface; and
- explicit schema, profile, and compatibility negotiation.

## 12.2 Interface Requirements

`DGS-NBI-001` — Every protocol profile shall map unambiguously to canonical Gateway requests and results.

`DGS-NBI-002` — A state-changing request shall carry a unique request identifier, client identity binding, target identity, operation version, deadline, and idempotency key when the operation profile requires one.

`DGS-NBI-003` — Every response shall identify request correlation, admission result, execution state, outcome certainty, observation freshness when applicable, and error classification.

`DGS-NBI-004` — A protocol adapter shall reject unknown required fields, illegal field combinations, out-of-range values, invalid encodings, and unsupported schema versions before admission.

`DGS-NBI-005` — Unknown optional fields may be accepted only when the negotiated schema declares forward-compatible ignore behavior and audit retains their presence.

`DGS-NBI-006` — No northbound endpoint shall expose arbitrary register address, field mask, raw wire opcode, protection-key sequence, physical buffer address, or unrestricted diagnostic clear.

# 13. Southbound Dragon Service Interface

## 13.1 Interface Use

Dragon Gateway shall use public typed lifecycle, configuration, observation, event, diagnostic, databus, monitoring, routing, safety-status, reset, and reconciliation services supplied by the Dragon SDK or device service. Southbound transport details remain governed by `RCA-DFC-SW-003`.

## 13.2 Southbound Requirements

`DGS-SBI-001` — Southbound communication shall authenticate the Gateway service identity and authorize only the typed capabilities required by the active deployment profile.

`DGS-SBI-002` — Gateway shall preserve transport-result, endpoint-result, completion-count, reconciliation, and active-readback information returned by the typed service.

`DGS-SBI-003` — Gateway shall not convert an ambiguous result into success, failure, timeout-only, or retryable status until required device reconciliation completes.

`DGS-SBI-004` — A southbound interface loss shall immediately suspend new state-changing dispatch for the affected device context.

`DGS-SBI-005` — In-process composition shall use the same typed interface contract and shall not introduce privileged shortcuts unavailable to hosted composition.

# 14. Startup, Discovery, and Compatibility

## 14.1 Startup Sequence

Gateway startup shall:

1. validate executable, configuration, policy, schema, protocol-profile, and dependency identities;
2. establish protected credentials and audit storage;
3. start administrative health observation without enabling external commands;
4. authenticate to the device service;
5. discover each configured device and obtain its validated compatibility result;
6. recover persistent request and idempotency state;
7. reconcile any request that was dispatched but lacked a persisted terminal outcome;
8. establish read-only observation and publication services;
9. enable only the state-changing operations allowed by compatibility, policy, profile, and recovered state; and
10. publish readiness separately for each endpoint and device context.

## 14.2 Compatibility Requirements

`DGS-START-001` — Gateway shall not accept external traffic before its schema, policy, audit, and authentication dependencies are ready.

`DGS-START-002` — State-changing endpoints shall remain unavailable until exact device compatibility or an explicitly approved capability profile is established.

`DGS-START-003` — Read-only partial-compatibility operation may be enabled only by a tested profile that preserves unknown values and labels all uncertain interpretations.

`DGS-START-004` — A recovered request record shall be matched to the same device identity and service epoch before reconciliation or result publication.

`DGS-START-005` — Readiness shall distinguish process alive, northbound reachable, policy ready, audit durable, southbound connected, device compatible, observation ready, and command ready.

# 15. Gateway Operating-State Model

## 15.1 Gateway States

| State | Meaning | State-changing admission |
|---|---|---|
| Starting | Configuration and dependencies are being validated | Prohibited |
| Isolated | Administrative interface is available; northbound service is disabled | Prohibited |
| Discovering | Southbound identity and compatibility are being established | Prohibited |
| Incompatible | Device or software contract is unsupported | Prohibited |
| Observing | Read-only typed observation is available | Prohibited |
| Command-ready | Authorized typed commands may be admitted | Permitted by policy |
| Reconciling | An uncertain prior operation is being resolved | Blocked for affected serialization scope |
| Degraded | One or more nonessential dependencies or delivery paths failed | Permitted only where explicit policy proves safety and auditability |
| Recovering | Restart, reconnect, or failover recovery is in progress | Prohibited |
| Service-failed | Required integrity, security, audit, or invariant condition failed | Prohibited |
| Stopping | New work is refused and accepted work is settling | Prohibited |

These are Gateway workflow states and shall not be presented as alternate Dragon Core primary operating states.

## 15.2 State Requirements

`DGS-STATE-001` — Gateway state shall be derived from explicit dependency, compatibility, recovery, policy, audit, and device-service qualifiers.

`DGS-STATE-002` — A device state observation shall retain its device-defined semantic class and shall not be collapsed into Gateway state.

`DGS-STATE-003` — Entry into Reconciling, Recovering, or Service-failed shall be durable when an outstanding state-changing result may otherwise be lost.

`DGS-STATE-004` — State transitions shall produce an audit record identifying trigger, prior state, new state, device context, and software epoch.

# 16. Authentication, Authorization, and Policy Enforcement

## 16.1 Admission Order

Authentication shall establish principal and credential validity. Authorization shall establish permitted operation and target. Policy evaluation shall apply deployment, tenant, parameter, state, time, rate, and maintenance constraints. These decisions are separate and shall remain auditable.

## 16.2 Requirements

`DGS-AUTH-001` — Every external command and protected observation shall be authenticated before schema-dependent processing can reveal protected information.

`DGS-AUTH-002` — Authorization shall default deny and shall grant the least typed capability required for the approved use.

`DGS-AUTH-003` — Authorization shall be evaluated at admission and revalidated immediately before dispatch when policy, session, or device state may have changed.

`DGS-AUTH-004` — Administrative, maintenance, configuration, reset, evidence-clear, and ordinary observation capabilities shall be separately assignable.

`DGS-AUTH-005` — Authorization shall not rely solely on network address, client-supplied role, endpoint obscurity, or possession of a Gateway idempotency key.

`DGS-AUTH-006` — Policy denial shall not disclose protected state beyond the minimum reason permitted by the active security policy.

`DGS-AUTH-007` — Policy changes shall be versioned, integrity-checked, atomically activated, and applied to new admissions without retroactively falsifying existing request records.

# 17. Command Admission and Validation

## 17.1 Admission Pipeline

Every external command shall pass, in order:

1. transport and peer validation;
2. authentication and session validation;
3. message framing and schema validation;
4. protocol and operation compatibility validation;
5. target-device resolution and compatibility validation;
6. authorization and deployment-policy evaluation;
7. parameter, cross-field, and operation-state validation;
8. replay, idempotency, rate, quota, and deadline validation;
9. audit-intent persistence; and
10. typed dispatch authorization.

## 17.2 Admission Requirements

`DGS-ADM-001` — Failure at any admission stage shall prevent southbound dispatch and shall produce one classified Gateway result.

`DGS-ADM-002` — Admission validation shall not be described as replacing validation performed by the Dragon SDK or device.

`DGS-ADM-003` — Target resolution shall bind the request to one discovered device identity before dispatch.

`DGS-ADM-004` — A client deadline already expired or too short to complete required admission and result handling shall be rejected before dispatch.

`DGS-ADM-005` — Gateway shall not split one requested atomic typed operation into externally visible partial operations unless the operation schema explicitly defines a transaction with compensating and reconciliation behavior.

`DGS-ADM-006` — Audit-intent persistence failure shall block state-changing dispatch.

# 18. Typed Functional Service Exposure

## 18.1 Service Families

| Service family | Permitted Gateway behavior |
|---|---|
| Identity and lifecycle | Typed discovery, compatibility, readiness, operating-state observation, and controlled lifecycle requests |
| Configuration | Desired-versus-active comparison, validation, protected staging, commit, and active readback |
| Interrupt and event | Typed pending-source observation, event retrieval, acknowledgement, and evidence-preserving publication |
| Monitoring | Typed current, threshold, validity, timeout, saturation, recovery, and source-provenance observations |
| Databus | Authorized queue, message, error, and routing services without raw register exposure |
| Fault and safety status | Active, sticky, primary, cause, inhibit, commanded, and effective state observation; authorized bounded recovery requests |
| Diagnostics | Snapshot, counter, reconciliation, and evidence retrieval through approved typed operations |
| Reset and recovery | Explicitly scoped, authorized, audited requests followed by mandatory recovery and readback |

## 18.2 Exposure Requirements

`DGS-SVC-001` — Each exposed operation shall declare its authorization scope, target type, parameters, preconditions, side effects, atomicity, completion model, outcome certainty, and audit class.

`DGS-SVC-002` — Requested, staged, active, commanded, effective, current, sticky, pending, acknowledged, cleared, snapshot, historical, cached, derived, and stale values shall remain distinguishable in schemas and results.

`DGS-SVC-003` — A device queue pop, acknowledgement, clear, reset, commit, transmit, or other side-effecting read or command shall never be exposed as an ordinary observation request.

`DGS-SVC-004` — Reserved, unsupported, test-only, and engineering-only capabilities shall not appear in a production-safe capability advertisement.

`DGS-SVC-005` — Gateway shall preserve per-source and per-destination identity when publishing interrupt, event, routing, queue, and loss information.

# 19. Observation, Event, and Diagnostic Publication

## 19.1 Observation Envelope

Every published observation shall carry, as applicable:

- Gateway and schema version;
- tenant and subscription scope;
- device identity and device-service epoch;
- observation type and semantic class;
- device timestamp or sequence when supplied;
- Gateway acquisition and publication times;
- freshness, validity, completeness, and stale indicators;
- raw, normalized, or derived provenance;
- source operation and correlation identity; and
- software-side loss or delivery-gap indicators.

## 19.2 Publication Requirements

`DGS-PUB-001` — Publication shall not convert a sticky historical indication into a current active condition or vice versa.

`DGS-PUB-002` — Cached data shall be labeled with acquisition time, source epoch, and stale state; it shall not be represented as a current device read.

`DGS-PUB-003` — Device-reported overflow, drop, or loss evidence shall remain separate from Gateway queue, storage, or delivery loss.

`DGS-PUB-004` — Event retrieval and external publication shall preserve device order and identity as supplied by the typed service; Gateway ordering shall be separately identified.

`DGS-PUB-005` — Aggregation, filtering, unit conversion, enrichment, and redaction shall retain traceable transformation provenance.

`DGS-PUB-006` — A publication acknowledgement by an external client shall not cause a device acknowledgement, clear, or pop unless a separately authorized command explicitly requests that side effect.

# 20. Configuration and State-Changing Workflows

## 20.1 Workflow Phases

State-changing workflows shall distinguish request validation, policy authorization, desired state, device staging, commit, definitive result, active readback, observation publication, and audit completion.

## 20.2 Requirements

`DGS-CFG-001` — Gateway shall validate a complete desired configuration object before requesting any device change.

`DGS-CFG-002` — Multi-field configuration shall use the typed staged-and-commit workflow supplied by the SDK when the device contract provides one.

`DGS-CFG-003` — Successful dispatch or transport completion shall not be reported as successful configuration activation.

`DGS-CFG-004` — Configuration success shall require a definitive operation result and applicable active readback matching the requested value.

`DGS-CFG-005` — A partial configuration workflow shall preserve the prior active state, completed steps, unresolved steps, and recovery disposition without claiming whole-object success.

`DGS-CFG-006` — Reset, clear, acknowledgement, pop, transmit, recovery, commit, and safety-affecting requests shall use distinct operation types and authorization scopes.

`DGS-CFG-007` — Broad clear-all, reset-all, or apply-all operations shall exist only when their exact bounded effect is defined, authorized, confirmed by policy, and independently verified.

# 21. Command Result and Completion Model

## 21.1 Request States

| Request state | Meaning |
|---|---|
| Received | Message was accepted by a protocol adapter but not yet admitted |
| Rejected | Admission failed before southbound dispatch |
| Admitted | Immutable request and audit intent were established |
| Dispatched | Typed southbound invocation began |
| Ambiguous | A definitive device result is not yet known |
| Reconciling | Device and service evidence are being used to determine outcome |
| Succeeded | Definitive success and required readback were established |
| Failed | Definitive failure was established |
| Cancelled-before-dispatch | Client cancellation occurred before any device effect was possible |
| Abandoned-delivery | Final outcome exists but delivery to the original client failed |

## 21.2 Result Requirements

`DGS-RES-001` — Every admitted request shall reach exactly one durable Gateway terminal outcome or remain durably marked Ambiguous/Reconciling until resolved by policy.

`DGS-RES-002` — Client connection loss shall change delivery state, not the underlying command outcome.

`DGS-RES-003` — Gateway errors, southbound transport errors, device results, policy denials, and external delivery errors shall remain separately classified.

`DGS-RES-004` — Success shall not be published before the typed service returns definitive success and any operation-required readback completes.

`DGS-RES-005` — Final results shall remain retrievable by authorized clients using request identity for the configured retention interval.

# 22. Idempotency, Deduplication, and Replay Control

## 22.1 Idempotency Scope

An idempotency key is scoped by authenticated principal or tenant, target device, operation type, canonical request content, schema version, and declared retention interval. It coordinates Gateway requests only; it is not device transaction identity and does not prove device outcome.

## 22.2 Requirements

`DGS-IDEM-001` — A repeated idempotency key with identical scoped content shall return or await the original Gateway request outcome and shall not create a second dispatch.

`DGS-IDEM-002` — Reuse of an idempotency key with different scoped content shall be rejected and audited as a conflict.

`DGS-IDEM-003` — Idempotency state for a dispatched state-changing request shall be durable before southbound invocation.

`DGS-IDEM-004` — Expired idempotency state shall not authorize blind replay of a prior state-changing operation.

`DGS-IDEM-005` — Authentication replay protection and Gateway request deduplication shall be independent controls.

`DGS-IDEM-006` — An idempotency match shall not replace device host reconciliation when the original operation outcome is ambiguous, as required by `SW-GW-002`.

# 23. Ambiguous-Outcome Reconciliation

## 23.1 Entry Conditions

Reconciliation is required when a state-changing southbound operation may have been accepted but its definitive response was lost, truncated, invalid, interrupted by process failure, or otherwise unavailable.

## 23.2 Reconciliation Requirements

`DGS-REC-001` — Gateway shall enter Ambiguous and persist the request before attempting any retry when device effect is possible but outcome is uncertain.

`DGS-REC-002` — Gateway shall use the typed host-reconciliation operation and applicable active state or evidence readback supplied by the device service.

`DGS-REC-003` — Reconciliation shall compare transaction identity, operation, target, completion information, terminal status, endpoint result, and applicable readback without redefining their device semantics.

`DGS-REC-004` — A state-changing request shall not be retried unless reconciliation and state readback prove that duplication cannot occur or establish definitive failure before effect.

`DGS-REC-005` — If reconciliation cannot establish a safe terminal outcome, Gateway shall preserve unresolved status, block conflicting operations in the affected serialization scope, and require the approved recovery authority.

`DGS-REC-006` — Client timeouts, retries, idempotency keys, replicated Gateway instances, and message-broker delivery guarantees shall not substitute for device reconciliation.

`DGS-REC-007` — Reconciliation evidence and the resulting decision shall be durably linked to the original request and audit record.

# 24. Disconnect, Restart, and Recovery

## 24.1 Recovery Triggers

Recovery shall be triggered by southbound disconnect, Gateway restart, device-service restart, device reset indication, compatibility change, policy-integrity failure, persistent-state inconsistency, failover, or an unresolved request.

## 24.2 Recovery Sequence

Gateway recovery shall:

1. suspend new state-changing admissions for affected contexts;
2. preserve available request, audit, publication, and dependency evidence;
3. reestablish authenticated dependencies;
4. rediscover device identity and compatibility;
5. reconcile outstanding dispatched requests;
6. acquire current lifecycle, fault, interrupt, event, diagnostic, and configuration state nondestructively;
7. compare recovered active state with external desired state without automatically changing it unless an approved policy authorizes reapplication;
8. rebuild subscriptions and mark discontinuities;
9. restore command readiness only after all mandatory qualifiers pass; and
10. publish one recovery result per affected context.

## 24.3 Requirements

`DGS-RCV-001` — Restart shall not assume that Dragon Core reset, retained prior configuration, or completed an outstanding operation.

`DGS-RCV-002` — Recovery shall not clear device evidence, reset the device, or reapply configuration until required pre-recovery evidence is captured and policy authorizes the action.

`DGS-RCV-003` — Cached observations from a prior device-service or Gateway epoch shall be marked stale until independently reacquired.

`DGS-RCV-004` — Network-client reconnection shall not cause southbound device reconnect or device reset.

`DGS-RCV-005` — Subscription recovery shall identify any unprovable delivery interval as a Gateway delivery gap.

# 25. Subscription, Queue, and Backpressure Management

## 25.1 Subscription Model

Each subscription shall declare client and tenant identity, authorized device set, observation types, filters, delivery mode, queue capacity, overflow policy, retention or cursor behavior, heartbeat policy, and expiry.

## 25.2 Requirements

`DGS-SUB-001` — Every in-memory and durable publication queue shall have a configured finite capacity and explicit overflow behavior.

`DGS-SUB-002` — A slow or failed subscriber shall not block device service, reconciliation, audit, or another subscriber beyond its assigned resource budget.

`DGS-SUB-003` — Queue overflow shall increment a Gateway-side loss counter, emit an audit or health record, and mark the affected delivery stream with a gap indication.

`DGS-SUB-004` — Lossless delivery shall be claimed only when durable retention, acknowledgement, replay, capacity, and recovery behavior have been verified end to end for the selected protocol profile.

`DGS-SUB-005` — Filters shall be applied only after authorization and shall not permit inference of unauthorized device identities or observations.

`DGS-SUB-006` — Subscription cursors shall identify Gateway publication order and shall not be represented as Dragon Core event sequence or timestamp values.

# 26. Data Transformation and Representation

## 26.1 Transformation Classes

| Class | Requirement |
|---|---|
| Direct typed value | Preserve source type, units, validity, and semantic class |
| Enumerated value | Preserve known identity; retain unknown numeric value when permitted |
| Timestamp | Preserve device raw timestamp separately from host acquisition and presentation time |
| Unit conversion | Apply only a versioned external rule and retain original value and units |
| Aggregation | Retain source membership, interval, loss state, and algorithm version |
| Redaction | Preserve record integrity metadata while removing only policy-selected external context |
| Enrichment | Label external metadata and its provenance separately from device evidence |

## 26.2 Requirements

`DGS-DATA-001` — Serialization shall use explicit widths, signedness, units, ranges, byte order, and null/unknown semantics.

`DGS-DATA-002` — Floating-point conversion shall not replace an exact integer device value in the authoritative record.

`DGS-DATA-003` — Installation calibration, engineering-unit conversion, and application interpretation shall remain external transformations under `PBIO-DATA-002` and `PBIO-DATA-004`.

`DGS-DATA-004` — A transformed value shall retain the source value, transformation identity, version, parameters, and result validity when used for audit or operational decisions.

`DGS-DATA-005` — Unknown enumerations and reserved bits shall not be assigned invented meanings.

# 27. Persistence and Data Custody

## 27.1 Persistent Data Classes

| Data class | Persistence purpose |
|---|---|
| Gateway configuration | Approved endpoints, device mappings, resource limits, and deployment settings |
| Policy metadata | Active policy identity, activation history, and decision linkage |
| Request journal | Admitted request, dispatch state, reconciliation state, and terminal outcome |
| Idempotency records | Scoped deduplication identity and linked request outcome |
| Subscription state | Durable cursor, acknowledgement, delivery, and gap state when enabled |
| Observation archive | Optional long-term external retention of typed observations and evidence |
| Audit records | Security, authorization, command, administration, recovery, and release evidence |
| Compatibility cache | Verified software, schema, protocol, and device relationships with provenance |

## 27.2 Requirements

`DGS-PERS-001` — Persistent records shall include schema version, record identity, creation time, source epoch, provenance, integrity metadata, and migration history where applicable.

`DGS-PERS-002` — A state-changing request journal entry shall be durably committed before southbound dispatch.

`DGS-PERS-003` — Storage failure shall block operations whose correctness depends on durable request, idempotency, audit, or delivery state.

`DGS-PERS-004` — Retention, archival, deletion, export, and legal-custody policy shall be explicit per deployment and data class.

`DGS-PERS-005` — Gateway persistence shall not be represented as replacing on-device sticky evidence, counters, queues, or event retention.

`DGS-PERS-006` — Schema migration shall validate the source, write a recoverable new form, verify integrity, and retain rollback or archive evidence before replacing the active store.

# 28. Logging, Audit, and Evidence Export

## 28.1 Record Types

Gateway shall record security events, session changes, policy decisions, admissions, dispatches, results, reconciliation, recovery, configuration activation, subscription loss, dependency failures, administrative actions, software faults, and release identity.

## 28.2 Requirements

`DGS-AUD-001` — Every state-changing request shall have one correlation chain from authenticated receipt through admission, dispatch, device outcome, readback, publication, and final delivery state.

`DGS-AUD-002` — Audit records shall be append-oriented, integrity-protected, access-controlled, time-correlated, and exportable with provenance.

`DGS-AUD-003` — Secrets, credential material, private keys, protected tokens, and unnecessary personal data shall not be logged.

`DGS-AUD-004` — Device evidence shall be stored without semantic alteration; Gateway context and interpretation shall be separate fields.

`DGS-AUD-005` — Clock uncertainty, time adjustment, missing wall-clock validity, and cross-system correlation limits shall be recorded rather than concealed.

`DGS-AUD-006` — Export shall identify selection criteria, schema, software release, source records, integrity result, redaction policy, and export time.

# 29. Security and Trust Boundaries

## 29.1 Trust Boundaries

Dragon Core protected-write and production-test controls are bounded hardware mechanisms, not cryptographic authentication, secure boot, network identity, key storage, or a software trust boundary. Dragon Gateway owns only its external software security allocation under `PBIO-SEC-002`.

## 29.2 Requirements

`DGS-SEC-001` — Networked production profiles shall use an approved authenticated and integrity-protected transport; confidential information shall additionally use approved encryption in transit.

`DGS-SEC-002` — Credentials and trust anchors shall be replaceable without rebuilding Gateway software.

`DGS-SEC-003` — Gateway shall validate peer identity, credential status, permitted algorithms, freshness, and transport protection before accepting protected traffic.

`DGS-SEC-004` — External input shall be bounded before allocation, parsing, decompression, deserialization, logging, or persistence.

`DGS-SEC-005` — Parsers shall reject malformed nesting, excessive size, duplicate ambiguous fields, invalid numeric forms, and resource-amplification attempts.

`DGS-SEC-006` — Production-safe deployment shall run with least privilege, read-only file systems where practical, restricted device permissions, controlled egress, and isolated administrative access.

`DGS-SEC-007` — Security failure shall fail closed for affected commands while preserving available health and audit reporting through an independent authorized path.

`DGS-SEC-008` — Vulnerability response, dependency review, credential rotation, patch deployment, rollback, and incident evidence shall follow controlled release and maintenance procedures.

# 30. Availability, Isolation, and Failover

## 30.1 Availability Model

Gateway availability shall not be confused with Dragon Core autonomous hardware supervision. Redundancy may improve external integration availability but shall not create concurrent device masters or duplicate state-changing dispatch.

## 30.2 Requirements

`DGS-AVL-001` — Exactly one device-service lifecycle owner and one command serializer shall be active for each physical device.

`DGS-AVL-002` — Redundant Gateway instances shall coordinate northbound ownership without sharing mutable request state through unverified eventual consistency.

`DGS-AVL-003` — Failover shall fence the prior dispatcher, recover durable request state, authenticate southbound access, rediscover compatibility, and reconcile outstanding operations before enabling commands.

`DGS-AVL-004` — A standby instance may serve explicitly stale or replicated read-only data only when provenance, age, and availability limits are declared.

`DGS-AVL-005` — Split-brain, lease uncertainty, or fencing failure shall prohibit state-changing dispatch.

`DGS-AVL-006` — Health checks shall distinguish application liveness, dependency readiness, device readiness, command readiness, publication readiness, and storage readiness.

# 31. Concurrency and Resource Management

## 31.1 Managed Resources

Gateway manages client sessions, authenticated connections, requests, southbound command slots, subscriptions, publication queues, worker capacity, timers, persistent records, file descriptors, memory, CPU, and bandwidth.

## 31.2 Requirements

`DGS-RSRC-001` — Every resource class shall have a configured limit, ownership rule, measurement, exhaustion behavior, and recovery rule.

`DGS-RSRC-002` — Per-client and per-tenant quotas shall prevent one external party from exhausting shared Gateway or device-service capacity.

`DGS-RSRC-003` — State-changing requests targeting the same device serialization scope shall preserve typed service ordering and shall not be concurrently dispatched when their effects can conflict.

`DGS-RSRC-004` — Read-only load shall be shed before reconciliation, audit, security, health, or accepted state-changing completion work is starved.

`DGS-RSRC-005` — Resource exhaustion shall produce Gateway-side evidence and shall not be merged with device queue-full, overflow, or busy results.

`DGS-RSRC-006` — Memory containing secrets or protected request data shall have bounded lifetime and shall be cleared when the platform and language permit reliable clearing.

# 32. Timing, Rate, and Performance

## 32.1 Timing Ownership

Device timing and performance are owned by the SRS. Gateway timing is an external software property and shall be configured to respect device-service deadlines and installation policy without restating device limits.

## 32.2 Requirements

`DGS-PERF-001` — Each deployment shall define deadlines for authentication, admission, dispatch, reconciliation, result persistence, observation acquisition, publication, recovery, and shutdown.

`DGS-PERF-002` — Rate limits shall be independently configurable by tenant, principal, endpoint, operation class, device, and deployment profile.

`DGS-PERF-003` — Rate limiting shall occur before scarce southbound or persistence resources are consumed where practical.

`DGS-PERF-004` — Gateway shall measure request latency by admission stage, southbound latency, reconciliation latency, queue occupancy, publication lag, persistence latency, rejection rate, and delivery loss.

`DGS-PERF-005` — Optimization shall not remove authentication, authorization, validation, audit intent, definitive-result checking, active readback, or reconciliation.

`DGS-PERF-006` — Load testing shall establish bounded behavior at configured maximum connections, requests, subscriptions, message sizes, event rates, and failure-recovery rates.

# 33. Error Handling and Degraded Operation

## 33.1 Error Classes

| Class | Examples | Required disposition |
|---|---|---|
| Client | Malformed schema, invalid parameter, expired deadline | Reject before dispatch; bounded disclosure |
| Authentication | Invalid, expired, revoked, or untrusted credential | Deny and audit under security policy |
| Authorization/policy | Disallowed operation, target, state, or rate | Deny before dispatch; retain decision evidence |
| Gateway | Invariant, parser, queue, worker, or internal-state failure | Isolate scope; preserve evidence; enter degraded or failed state |
| Southbound | Service disconnect, timeout, incompatible version | Suspend affected commands; reconnect and recover |
| Device result | Access, protection, configuration, resource, or state rejection | Preserve exact typed class; do not reinterpret |
| Ambiguous | Possible accepted state change without definitive response | Persist, reconcile, and prohibit blind retry |
| Persistence | Journal, audit, idempotency, or delivery-store failure | Block dependent operations and report degraded state |
| Publication | Slow consumer, overflow, delivery failure | Isolate subscriber; mark Gateway-side gap |
| Security | Integrity, replay, credential, or trust failure | Fail closed for affected capability and audit |

## 33.2 Requirements

`DGS-ERR-001` — Errors shall preserve origin, certainty, retry eligibility, affected scope, and recovery action.

`DGS-ERR-002` — Read-only requests may use bounded retry only when freshness and duplicate acquisition are acceptable.

`DGS-ERR-003` — Busy and transient resource responses shall use bounded backoff within the original deadline and policy.

`DGS-ERR-004` — A state-changing operation shall follow `SW-GW-003` and shall not be retried without definitive failure-before-effect or completed reconciliation.

`DGS-ERR-005` — Degraded operation shall explicitly list unavailable capabilities and shall never silently weaken authentication, audit, validation, compatibility, or result certainty.

# 34. Human Administration and Automation Interfaces

## 34.1 Administration Interface

The administrative interface shall support health observation, configuration validation, policy activation, credential-reference management, device mapping, protocol-profile activation, controlled drain, restart, evidence export, and release identification. It shall not provide an unrestricted Dragon Core command shell.

## 34.2 Requirements

`DGS-ADMIN-001` — Administrative state changes shall require separate authorization and shall produce durable audit records.

`DGS-ADMIN-002` — Configuration validation and dry-run output shall identify every affected endpoint, device context, policy, resource limit, and restart requirement before activation.

`DGS-ADMIN-003` — Administrative health shall expose Gateway dependencies and epochs without exposing secrets or unauthorized device data.

`DGS-ADMIN-004` — Automation interfaces shall use the same canonical operations, authorization, admission, result, and audit paths as other external clients.

`DGS-ADMIN-005` — Batch tools shall stop on ambiguity, preserve completed results, and shall not infer rollback of a device effect.

# 35. Portability and Platform Adaptation

## 35.1 Portability Model

Gateway core behavior shall remain independent of processor architecture, operating system, network library, database engine, and protocol framework. Platform and protocol differences shall be confined to approved adapters.

## 35.2 Requirements

`DGS-PORT-001` — Canonical data models shall use explicit widths, units, ranges, optionality, and serialization rules independent of host padding and endianness.

`DGS-PORT-002` — Monotonic durations and wall-clock timestamps shall use distinct types and explicit units.

`DGS-PORT-003` — A new northbound adapter shall pass the common canonical-operation, security, admission, result, recovery, and fault-injection suites.

`DGS-PORT-004` — A new storage adapter shall prove atomic journal, idempotency, audit, migration, failure, and recovery semantics before production use.

`DGS-PORT-005` — Portability shall not be achieved by weakening resource bounds, transport security, durability, or typed result semantics.

# 36. Internal and External Software Interfaces

## 36.1 Required Interfaces

| Interface | Producer | Consumer | Required content |
|---|---|---|---|
| Canonical command | Northbound adapter | Admission pipeline | Typed identity, target, operation, parameters, deadline, idempotency, schema |
| Admission decision | Admission pipeline | Request coordinator | Allow/deny, constraints, policy version, audit correlation |
| Typed dispatch | Request coordinator | Southbound service client | Authorized typed operation and immutable request context |
| Typed result | Southbound service client | Request coordinator | Definitive/ambiguous class, device/service result, completion, readback |
| Observation stream | Southbound service client | Publication service | Typed value, semantic class, provenance, freshness, source epoch |
| Publication delivery | Publication service | Protocol adapter | Authorized envelope, cursor, gap, delivery state |
| Persistence transaction | Coordinator/services | Persistence adapter | Atomic request, audit, idempotency, subscription, or record operation |
| Health report | All components | Health and administration service | Readiness, limits, failures, epochs, and metrics |

## 36.2 Interface Requirements

`DGS-INTF-001` — Internal interfaces shall use typed immutable messages or explicitly synchronized ownership.

`DGS-INTF-002` — Every asynchronous message shall carry correlation, source epoch, target scope, and cancellation or expiry semantics.

`DGS-INTF-003` — Interface errors shall be returned as structured classes and shall not rely on log parsing.

`DGS-INTF-004` — Internal APIs shall not expose credentials, mutable global policy objects, raw device handles, or unrestricted generated-register access to protocol adapters.

`DGS-INTF-005` — Interface contracts shall be versioned, unit tested, integration tested, and included in release compatibility evidence.

# 37. Protocol, Schema, and Compatibility Versioning

## 37.1 Independent Version Axes

| Version axis | Owner and purpose |
|---|---|
| Dragon Core product/revision | Controlling technical specifications |
| Register-map compatibility | Register Map and generated-binding provenance |
| Dragon SDK API | Governing software API specifications |
| Device-service interface | Device-service package and compatibility declaration |
| Canonical Gateway model | This specification and controlled Gateway schema baseline |
| Northbound protocol profile | Selected adapter binding, transport, encoding, security, and endpoint contract |
| Deployment policy | Installation-controlled authorization and operational constraints |
| Persistent schema | Gateway storage and migration contract |

## 37.2 Requirements

`DGS-VER-001` — Northbound protocol and schema versions shall vary independently from the Dragon Core register-map revision while declaring tested compatibility, as required by `SW-GW-005`.

`DGS-VER-002` — Negotiation shall select only a mutually supported, enabled, and security-approved protocol profile and schema version.

`DGS-VER-003` — Unknown major versions, changed required semantics, or missing required capabilities shall block affected operations.

`DGS-VER-004` — Additive optional fields shall not alter existing field meaning, default behavior, authorization, or side effects.

`DGS-VER-005` — Deprecated operations shall remain explicit, documented, observable, and tested until removed by the declared compatibility policy.

`DGS-VER-006` — Compatibility matrices shall be generated or machine-validated release artifacts and shall identify evidence for every supported combination.

# 38. Software Verification and Validation

## 38.1 Verification Levels

| Level | Required focus |
|---|---|
| Unit | Parsers, validators, policy hooks, state machines, transformations, queues, and error mapping |
| Component | Protocol adapters, admission, coordinator, publication, persistence, audit, and health behavior |
| Integration | Authenticated northbound, southbound typed service, storage, identity provider, and time service |
| Host conformance | Correct use of Dragon SDK, compatibility, results, readback, reconciliation, and recovery |
| Security | Threat model, authentication, authorization, replay, fuzzing, resource abuse, isolation, secrets, and audit |
| Fault injection | Disconnect, process death, storage failure, partial persistence, timeout, response loss, overflow, and failover |
| Performance | Maximum configured clients, subscriptions, requests, observations, message sizes, and recovery load |
| Acceptance | End-to-end authorized workflows, evidence, packaging, deployment, upgrade, rollback, and operations |

## 38.2 Mandatory Verification Subjects

Verification shall include:

- startup with valid, invalid, missing, and incompatible configuration inputs;
- exact and partial device compatibility handling;
- authentication success, failure, expiry, revocation, and rotation;
- authorization by tenant, role, operation, target, parameter, state, and profile;
- malformed, oversized, nested, duplicate-field, unknown-version, and fuzzed input;
- rate, quota, timeout, cancellation, and resource-exhaustion behavior;
- read-only observation freshness, staleness, semantic-class preservation, and transformation provenance;
- every exposed state-changing operation's admission, dispatch, definitive result, active readback, and audit chain;
- idempotency duplicate, conflict, persistence, expiry, restart, and concurrent-request cases;
- response loss before and after possible device acceptance, reconciliation, and blind-retry prohibition;
- client disconnect after dispatch and final-result retrieval after reconnect;
- Gateway, device-service, storage, identity-provider, network, and time-service failure;
- subscriber backpressure, overflow, durable replay, gap indication, and isolation;
- Gateway restart and redundant-instance failover with fencing and unresolved work;
- production-safe exclusion of engineering, raw, test, and injection capabilities;
- schema negotiation, compatibility matrices, migrations, upgrade, and rollback; and
- equivalence of canonical behavior across every released protocol and platform adapter.

## 38.3 Verification Requirements

`DGS-VV-001` — Each normative `DGS-*` requirement shall trace to one or more objective verification cases and retained evidence.

`DGS-VV-002` — Test oracles for device outcomes shall derive from controlling specifications or independent typed reference models, not from Gateway implementation logic.

`DGS-VV-003` — Security testing shall include static analysis, dependency analysis, credential-leak checks, parser fuzzing, negative authorization, replay, and denial-of-service bounds.

`DGS-VV-004` — Fault injection shall include failures at every persistence and dispatch boundary needed to prove no lost or duplicated state-changing operation.

`DGS-VV-005` — Host-boundary scenarios shall align with the Verification Plan without redefining any controlling case or claiming device conformity beyond its outcome.

`DGS-VV-006` — Release acceptance shall run against the exact binaries, schemas, policies, protocol profiles, storage migrations, and manifests intended for delivery.

# 39. Traceability and Change Control

## 39.1 Trace Model

Gateway requirements shall trace upstream to governing software architecture and applicable controlling technical ownership, then downstream to design, canonical schemas, policy controls, source components, tests, security evidence, release artifacts, and operational documentation.

This specification shall not reproduce the RTM relationships among SRS, Architecture, Register Map, RTL, and Verification Plan identifiers.

## 39.2 Required Trace Links

| Source | Required downstream link |
|---|---|
| `DGS-*` requirement | Component or interface allocation and verification case |
| Canonical operation | Schema item, authorization scope, handler, tests, and documentation |
| Protocol binding | Canonical operation, adapter source, conformance tests, and compatibility profile |
| Policy capability | Operation, parameter constraints, decision tests, and audit fields |
| Persistent record | Schema, migration, integrity test, recovery test, and retention rule |
| Release artifact | Source/build identity, manifest, compatibility evidence, and approval |

## 39.3 Requirements

`DGS-TRACE-001` — Every normative identifier in this specification shall be unique and resolved.

`DGS-TRACE-002` — A schema field copied from a generated device model shall retain machine-verifiable provenance to its generated source.

`DGS-TRACE-003` — A change to an exposed operation shall analyze authorization, policy, idempotency, persistence, audit, compatibility, documentation, and client impact.

`DGS-TRACE-004` — A controlling-specification or governing-software change shall trigger impact analysis before a dependent Gateway release.

`DGS-TRACE-005` — Trace shall not be inferred from filename similarity, source directory, endpoint name, or undocumented convention.

# 40. Build, Package, Deployment, and Release

## 40.1 Required Packages

| Package | Required content |
|---|---|
| Gateway runtime | Executables, libraries, runtime dependencies, service definitions, and health configuration |
| Schema package | Canonical schemas, protocol bindings, validators, compatibility metadata, and documentation |
| Policy package | Policy schema, approved baseline policies or templates, integrity metadata, and activation guidance |
| Migration package | Persistent-schema migrations, validation, rollback or recovery procedures, and tests |
| Administration package | Least-privilege administration client, deployment examples, diagnostics, and operating procedures |
| Verification package | Tests, fixtures, reports, coverage, security evidence, and acceptance results |
| Release record | Manifest, hashes, signatures when selected, SBOM, provenance, approvals, and archival identity |

## 40.2 Release Requirements

`DGS-REL-001` — Builds and releases shall comply with `RCA-DFC-SW-004`, `RCA-DFC-SW-005`, and `RCA-DFC-SW-006`.

`DGS-REL-002` — Release artifacts shall be reproducible from controlled sources, toolchains, dependencies, generators, schemas, policies, and build profiles.

`DGS-REL-003` — The manifest shall identify every enabled endpoint, protocol profile, schema, policy interface, storage schema, device compatibility profile, and engineering capability state.

`DGS-REL-004` — Production-safe packages shall exclude test credentials, development endpoints, unrestricted diagnostics, fault injection, raw access, and hidden feature flags.

`DGS-REL-005` — Upgrade shall validate compatibility and migration readiness before traffic activation; rollback shall preserve request, idempotency, audit, and reconciliation integrity.

`DGS-REL-006` — A release shall not be approved with unresolved security findings, ambiguous requirements, failed mandatory tests, unverified compatibility claims, or known loss/duplication defects in state-changing workflows.

# 41. Deliverables

## 41.1 Required Deliverables

The Dragon Gateway baseline shall deliver:

1. approved source code and build definitions;
2. Gateway runtime packages for each approved platform profile;
3. canonical command, result, observation, notification, identity, and error schemas;
4. each approved northbound protocol profile and adapter;
5. southbound device-service integration component;
6. policy schema, authorization capability catalog, and approved policy templates;
7. persistent schemas and migrations;
8. administration, deployment, security, recovery, upgrade, and rollback procedures;
9. API and client-integration documentation with safe examples;
10. automated verification suites and fixtures;
11. requirements traceability and compatibility matrices;
12. security threat model, analysis results, and residual-risk disposition;
13. performance and resource-limit evidence;
14. software bill of materials, provenance, release manifest, and integrity data; and
15. approved verification, acceptance, and release evidence.

## 41.2 Delivery Requirements

`DGS-DEL-001` — Delivered examples shall use typed operations, bounded deadlines, authorization, idempotency where required, definitive-result handling, and reconciliation-safe behavior.

`DGS-DEL-002` — No delivered example or utility shall demonstrate unrestricted register access, blind retry, implicit evidence clearing, or authentication bypass.

`DGS-DEL-003` — Documentation shall distinguish Gateway behavior, device behavior, deployment policy, external-system responsibility, and installation responsibility.

# 42. Exit Criteria

Dragon Gateway Revision A is eligible for technical-baseline approval only when all of the following are satisfied:

1. every section of this specification is complete and internally consistent;
2. every normative identifier is unique and traced;
3. no requirement redefines a subject owned by a controlling specification;
4. every exposed operation has a typed schema, authorization scope, admission rule, result model, audit rule, and verification evidence;
5. startup, compatibility, observation, state-changing, idempotency, ambiguity, restart, recovery, failover, and shutdown workflows pass required tests;
6. production-safe packages contain no engineering-only, test-only, injection, raw-access, or hidden capabilities;
7. parser fuzzing, negative authorization, replay, resource-abuse, credential, dependency, and security tests pass;
8. persistent request, idempotency, audit, migration, recovery, and rollback behavior passes fault-injection testing;
9. every released protocol and platform adapter passes the common conformance suite;
10. performance and resource limits are measured and enforced;
11. release manifests, provenance, compatibility matrices, SBOM, integrity evidence, and archival records are complete;
12. all blocking defects and security findings are closed or formally dispositioned under the governing software process; and
13. any discovered controlling-specification defect has been corrected by its owning document before dependent implementation approval.

# 43. Baseline Statement

## 43.1 Baseline Declaration

This document establishes the Dragon Gateway Software Specification, Revision A, for Dragon Core Revision A.

Dragon Gateway is an external-host integration service. It translates authenticated, authorized, schema-valid external requests into typed Dragon services and publishes typed observations and definitive results. It does not execute inside Dragon Core, own the SPI transport, expose an unrestricted remote register map, replace device evidence, or assume hardware safety responsibility.

## 43.2 Governing Relationship

The eight-document technical set identified by `RCA-DFC-CHTR-002`, Section 3.1 remains controlling for product scope, responsibility allocation, device behavior, internal architecture, registers, technical verification, trace relationships, and RTL rules. `RCA-DFC-SW-001` through `RCA-DFC-SW-006` govern the shared external-host software architecture, APIs, coding, verification, and release process. This document owns only the subordinate Dragon Gateway software allocation.

## 43.3 Fixed Baseline Conclusions

The Revision A baseline fixes the following software conclusions:

1. Dragon Gateway executes entirely outside the fabricated Dragon Core device.
2. The privileged device service or equivalent in-process service remains the sole physical-device and command-serializer owner.
3. Northbound clients use typed Gateway operations rather than arbitrary register access.
4. Every external command passes authentication, authorization, schema validation, compatibility validation, rate limiting, policy enforcement, and audit-intent persistence before dispatch.
5. Gateway idempotency and authentication replay controls do not substitute for device host reconciliation.
6. A state-changing request is never blindly retried after a possibly accepted operation.
7. Success requires a definitive device result and applicable active readback.
8. Observations preserve current, sticky, historical, cached, derived, stale, device-loss, and Gateway-loss distinctions.
9. Gateway disconnection does not interrupt local device supervision, evidence retrieval, or configured watchdog scheduling.
10. Northbound protocol and schema versions remain independent from the Dragon Core register-map revision while declaring tested compatibility.
11. Production-safe packages exclude engineering, raw-access, test, injection, and hidden capabilities.
12. Redundancy never permits concurrent southbound command ownership for one physical device.

## 43.4 Controlling-Specification Disposition

No required change to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, or `RCA-DFC-RTL-STD-002` was identified while establishing this baseline.

Deployment selection of an external transport, encoding, identity provider, trust anchors, credential mechanism, network topology, storage engine, and installation policy is intentionally subordinate to this specification and the applicable system integration artifacts. Those selections shall preserve the canonical semantics and verification obligations defined here and do not redefine the Dragon Core product contract.

## 43.5 Change Control

Changes to this specification require impact analysis across canonical schemas, protocol profiles, authorization capabilities, policy, request state, idempotency, persistence, audit, security, recovery, compatibility, verification, documentation, packaging, and release evidence. A change affecting a controlling technical subject shall first be made in its owning specification.

## 43.6 Approval Statement

Approval of this document authorizes detailed design, implementation, verification, packaging, and release of Dragon Gateway Revision A subject to the governing software specifications and the eight controlling Dragon Flight technical specifications.
