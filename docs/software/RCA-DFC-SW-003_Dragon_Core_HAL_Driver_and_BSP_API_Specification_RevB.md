**DRAGON CORE™ HAL, DRIVER, AND BSP API SPECIFICATION**

Document Number: RCA-DFC-SW-003
Revision: B
Status: Technical Baseline
Product: Dragon Core™ Revision A
Program: Dragon Flight™ Core ASIC Development Program
Organization: Royal Cubit Aerospace

# Revision History

| Revision | Date       | Description | Author |
|----------|------------|-------------|--------|
| A | Undated | Historical initial baseline supplied as reference only | Royal Cubit Aerospace |
| B | 2026-08-07 | Rebuilt beneath the eight controlling specifications for the external-host HAL, driver, and BSP API | Royal Cubit Aerospace |

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
4. Software Configuration Item Identification
5. Prototype and Production Execution Model
6. Software Stack Boundary Definition
7. Repository and File Organization
8. Public Header File Architecture
9. Common Type Definitions
10. Status and Error Code Model
11. Version Identification API
12. Compile-Time Configuration Model
13. BSP Interface Requirements
14. VisionFive 2/ECP5 Validation-Host BSP Interface
15. Production External-Host BSP Interface
16. SPI Transport Primitive API
17. Memory Barrier and Ordering API
18. Critical Section and Locking API
19. Host Interrupt Primitive API
20. Timing and Deadline Primitive API
21. HAL Initialization Model
22. Device Discovery and Compatibility Model
23. Register Access API
24. Configuration Workflow API
25. Interrupt Controller API
26. Event Logger API
27. Timestamp API
28. GPIO API
29. Rotor RPM API
30. Engine RPM API
31. Pulse/Frequency Measurement API
32. Sensor Monitor API
33. System Health Monitor API
34. Watchdog API
35. Fault Manager API
36. Interlock Engine API
37. Lost-Link Supervisor API
38. Safety Output API
39. ARINC 429 API
40. Classical CAN API
41. UART API
42. Databus Routing API
43. Mask-Defined User Logic API
44. User-Configurable Routing API
45. Driver Layer Responsibilities
46. Driver/HAL Boundary Rules
47. Callback and Notification Model
48. Thread Safety and Interrupt-Context Rules
49. Diagnostics and Engineering API
50. Initialization Sequence
51. Runtime Service Sequence
52. FPGA Validation Access Sequence
53. Production ASIC Access Sequence
54. Unit Test Requirements
55. FPGA Validation Requirements
56. ASIC Bring-Up Validation Requirements
57. Deliverables
58. Exit Criteria
59. Baseline Statement

# 1. Purpose

This specification defines the implementation contract for the Dragon Core Revision A Hardware Abstraction Layer (HAL), portable driver library, and Board Support Package (BSP) APIs. All three are executable software components that run on a processor outside the fabricated Dragon Core device.

Dragon Core is a processor-free ASIC. It contains no embedded processor, firmware, bootloader, operating system, BSP, executable memory, software runtime, stack, or heap, as controlled by `CHTR-TECH-001` through `CHTR-TECH-005` and `CHTR-EXCL-002`.

This specification is subordinate to the eight controlling technical specifications identified by `RCA-DFC-CHTR-002`, Section 3.1, and implements the software architecture of `RCA-DFC-SW-001` Revision C and the external embedded-host firmware requirements of `RCA-DFC-SW-002` Revision B. It owns software-only API names, types, call sequencing, result representations, software concurrency rules, storage ownership, BSP adaptation, and driver verification obligations. It does not redefine any controlling technical fact.

`API-DOC-001` — An implementation shall obtain device behavior, interface timing and framing, internal architecture, register semantics, verification-case definitions, trace relationships, and RTL rules only from their controlling owners.

`API-DOC-002` — A conflict, ambiguity, omission, or unimplementable controlling contract shall be reported for correction in the owning specification; this API specification and its implementation shall not invent substitute device behavior.

# 2. Scope

## 2.1 Included Scope

This specification covers:

- the portable ISO/IEC 9899:2018 C17 public API;
- BSP services for SPI, host interrupt, monotonic time, locking, ordering, logging, and optional persistence integration;
- device-context construction, discovery, compatibility, lifecycle, and recovery;
- SPI command serialization, response validation, partial completion, and reconciliation;
- generated Register-Map bindings and typed module services;
- protected, staged, snapshot, pop, push, clear, service, reset, and recovery workflows;
- callback and deferred-notification behavior;
- production and engineering-profile separation; and
- unit, integration, FPGA-validation, and post-silicon software verification obligations.

## 2.2 Excluded Scope

This specification does not define:

- software or firmware inside Dragon Core;
- an ASIC-local BSP, processor bus, direct MMIO aperture, processor exception model, cache policy, or processor boot sequence;
- device behavior, register offsets, field encodings, reset values, legal values, or side effects;
- OpenFrame physical implementation, ECP5 wrapper implementation, board wiring, electrical conditioning, transceivers, or aircraft installation;
- application-specific control, navigation, guidance, mission, or aircraft-energy policy;
- certification basis, operating-system selection, application persistence schema, or user-interface design; or
- hidden diagnostic, scan, test, platform-private, or RTL-hierarchical access.

## 2.3 Product and Safety Boundary

The HAL and driver may configure, observe, service, retrieve, and request operations permitted by the controlling host-visible contract. They shall not be credited with a safety responsibility assigned to Dragon Core hardware and shall not bypass, suppress, emulate, or replace hardware enforcement. Host absence, delay, malformed traffic, or software failure shall not be treated as permission to weaken the device contract controlled by `PBIO-HOST-003` through `PBIO-HOST-009`.

# 3. Applicable Documents

## 3.1 Controlling Technical Specifications

| Document | Consumed subject |
|---|---|
| `RCA-DFC-CHTR-002` | Product mission, exclusions, external-host model, selected platforms, and single-owner rules |
| `RCA-DFC-PBIO-002` | Device, host, software, board, platform, data-custody, and verification responsibilities |
| `RCA-DFC-SRS-002` | Externally observable device behavior, SPI contract, timing, safety, reliability, and logical interfaces |
| `RCA-DFC-ARCH-002` | Internal protocol bindings, allocations, states, priorities, algorithms, and logical-wrapper architecture |
| `RCA-DFC-REG-002` | Complete host-visible register contract and generated-binding source |
| `RCA-DFC-VP-002` | Controlling verification methods, cases, coverage, outcomes, and evidence |
| `RCA-DFC-RTM-002` | Relationships among existing controlling identifiers |
| `RCA-DFC-RTL-STD-002` | RTL implementation rules consumed for boundary awareness only |

## 3.2 Governing Software Specifications

| Document | Relationship |
|---|---|
| `RCA-DFC-SW-001`, Revision C | Governing external-host software architecture |
| `RCA-DFC-SW-002`, Revision B | Governing external embedded-host firmware implementation requirements |

## 3.3 Historical Reference

`RCA-DFC-SW-003`, Revision A was used only as historical input. Its assumptions of an embedded Dragon Core RISC-V processor, ASIC-local firmware, ASIC-local BSP, direct MMIO, byte or halfword register access, and separate production programming model are not part of Revision B.

## 3.4 Authority and Change Flags

`API-DOC-003` — The eight controlling specifications retain sole authority for their assigned subjects under `CHTR-DOC-001` through `CHTR-DOC-007`.

`API-DOC-004` — Generated headers, implementation code, examples, test doubles, FPGA behavior, and prior software shall not become alternate technical authorities.

No change to a controlling specification is required to establish this Revision B baseline. Any future implementation finding that requires new device behavior, register meaning, interface behavior, verification definition, trace relationship, or RTL rule shall be raised against the applicable controlling owner before dependent implementation proceeds.

# 4. Software Configuration Item Identification

## 4.1 Configuration Items

| Configuration item | Purpose | Execution location |
|---|---|---|
| `libdfc_driver` | Portable typed Dragon Core device API and workflows | External host processor |
| `dfc_bsp_<platform>` | Platform adaptation for SPI, interrupt, time, locking, ordering, and diagnostics | External host processor |
| `dfc_reg_bindings` | Generated C definitions and access metadata derived from the Register Map-controlled source | Build-time generated external-host artifact |
| `dfc_test_support` | Test doubles, fault injection at software boundaries, protocol oracle, and fixtures | External verification host |

## 4.2 Identification Rules

`API-CI-001` — Each released library shall identify its semantic API version, source revision, generated-binding identity, supported product revision, supported register-map revision range, build options, target profile, compiler, and controlling-specification revisions.

`API-CI-002` — Software API version, persistent-schema version, product revision, register-map revision, capability bitmap, FPGA image identity, and device build identity are independent values.

`API-CI-003` — Public production symbols shall use the `dfc_` prefix. BSP symbols shall use `dfc_bsp_`. Generated symbols shall use `DFC_REG_`, `DFC_FLD_`, or another generator-owned prefix declared in the generated manifest.

# 5. Prototype and Production Execution Model

## 5.1 Common External-Host Model

The portable driver always runs on an external processor and communicates through the SRS-defined SPI host transport and Register-Map-defined logical programming model. The same portable library shall be usable with both the selected VisionFive 2/ECP5 validation environment and a production external host connected to the fabricated OpenFrame ASIC.

## 5.2 Platform Variation

| Subject | FPGA validation | Production ASIC use |
|---|---|---|
| Dragon Core realization | Common RTL through ECP5 wrapper | Common logical design through OpenFrame ASIC wrapper |
| Host processor | VisionFive 2 selected for validation | External processor selected by system integrator |
| Software location | VisionFive 2 memory | Production host memory |
| Device access | SRS-defined SPI | Same SRS-defined SPI |
| Programming model | Register Map-controlled contract | Same Register Map-controlled contract |
| Platform adaptation | VisionFive 2 BSP | Production-host BSP |

`API-EXEC-001` — No portable-layer behavior shall branch on FPGA versus ASIC except for validated implementation identity, diagnostics, or platform capability outside the logical device contract.

`API-EXEC-002` — FPGA-only visibility, wrapper registers, scan access, test paths, and simulator backdoors shall not be dependencies of production driver behavior.

# 6. Software Stack Boundary Definition

## 6.1 Layer Allocation

| Layer | Owns | Shall not own |
|---|---|---|
| Application or firmware service | Configuration policy, scheduling, persistence, interpretation, user workflow | Wire framing, register encoding, hardware safety enforcement |
| Portable driver | Serialization, protocol validation, typed register workflows, reconciliation, lifecycle | Platform electrical control, device behavior, application policy |
| HAL coordination | Device-context state, command serialization, deferred service, platform-neutral primitives | Register redefinition or platform-private device access |
| BSP | Host-controller use, chip-select continuity, host interrupt integration, monotonic time, locks, barriers | Dragon Core register meaning or module policy |
| Generated bindings | Exact machine-readable projection of the Register Map contract | Hand-authored policy or copied alternate register definitions |
| Dragon Core | Controlling device-side behavior | External software execution or persistence |

## 6.2 Dependency Rules

`API-STACK-001` — Applications shall use typed driver APIs for production operation. Direct BSP SPI use is reserved for driver implementation and approved verification tools.

`API-STACK-002` — Portable driver code shall depend on `dfc_bsp.h`, generated bindings, fixed-width C types, and explicitly declared software services only.

`API-STACK-003` — A BSP shall not parse Dragon Core registers or implement device workflows.

`API-STACK-004` — Exactly one command coordinator shall own an open device context's SPI transaction stream.

# 7. Repository and File Organization

## 7.1 Required Layout

| Path | Content |
|---|---|
| `include/dfc/` | Stable public headers |
| `src/core/` | Portable lifecycle, command, result, and reconciliation implementation |
| `src/modules/` | Typed module API implementations |
| `generated/` | Generated bindings, metadata, and generation manifest |
| `bsp/<platform>/` | Platform-specific BSP implementations |
| `tests/unit/` | Portable unit tests and BSP test doubles |
| `tests/integration/` | Protocol, device-model, and hardware-in-the-loop tests |
| `examples/` | Nonnormative examples built against public APIs |
| `tools/` | Binding checks, manifest validation, and release utilities |

`API-REPO-001` — Generated artifacts shall not be manually edited. Their source identity and generator version shall be recorded.

`API-REPO-002` — Platform-specific includes, compiler intrinsics, operating-system headers, and controller register definitions shall remain below `bsp/<platform>/`.

`API-REPO-003` — Examples shall be compiled and tested but shall not establish behavior absent from this specification.

# 8. Public Header File Architecture

## 8.1 Required Headers

| Header | Purpose |
|---|---|
| `dfc_types.h` | Fixed-width public types, opaque handles, deadlines, and immutable observations |
| `dfc_status.h` | Software result, device result, transport result, and outcome classification |
| `dfc_version.h` | API and implementation identity |
| `dfc_bsp.h` | BSP operation table and capability contract |
| `dfc_device.h` | Context construction, discovery, lifecycle, and recovery |
| `dfc_register.h` | Controlled scalar and engineering register operations |
| `dfc_config.h` | Desired-configuration and active-readback workflow |
| `dfc_interrupt.h` | Interrupt source service |
| `dfc_event.h` | Event snapshot, read, pop, and clear workflow |
| `dfc_timestamp.h` | Raw/correlated time access and correlation workflow |
| `dfc_gpio.h` | GPIO configuration, command, and observation |
| `dfc_monitor.h` | Rotor, engine, pulse, sensor, and health services |
| `dfc_safety.h` | Watchdog, fault, interlock, lost-link, and safety-output services |
| `dfc_databus.h` | ARINC 429, Classical CAN, UART, and databus routing services |
| `dfc_user.h` | Revision A user-logic diagnostics and user-routing services |
| `dfc_diagnostics.h` | Host, reset, clock, loss, counter, and engineering diagnostics |
| `dfc.h` | Convenience aggregate header only |

## 8.2 Header Rules

`API-HDR-001` — Every public declaration shall be valid C17 and C++-linkage compatible through `extern "C"` guards without requiring C++.

`API-HDR-002` — Public structures shall use fixed-width types, explicit units, declared ownership, and explicit reserved members initialized to zero where ABI growth is permitted.

`API-HDR-003` — Public wire or register structures shall not rely on compiler packing, bitfields, host alignment, host endianness, or native enumeration size.

`API-HDR-004` — Public headers shall not expose platform controller types or internal lock objects.

## 8.3 Prototype Conventions

The function names in Sections 21 through 49 are normative. Exact declarations shall follow these C17 templates, replacing the italicized semantic type with the function-specific public type named by its table contract:

| Operation class | Required declaration form |
|---|---|
| Nondestructive read | `dfc_status_t name(dfc_device_t *device, dfc_deadline_t deadline, observation_type *out_observation);` |
| Indexed nondestructive read | `dfc_status_t name(dfc_device_t *device, uint8_t index, dfc_deadline_t deadline, observation_type *out_observation);` |
| Configuration or state change | `dfc_status_t name(dfc_device_t *device, const request_type *request, dfc_deadline_t deadline, dfc_command_result_t *out_result);` |
| Indexed configuration or state change | `dfc_status_t name(dfc_device_t *device, uint8_t index, const request_type *request, dfc_deadline_t deadline, dfc_command_result_t *out_result);` |
| Typed mask clear/acknowledge | `dfc_status_t name(dfc_device_t *device, mask_type mask, dfc_deadline_t deadline, dfc_command_result_t *out_result);` |
| Nonblocking software notification | `dfc_status_t name(dfc_device_t *device);` |

All pointers are non-null unless the individual declaration explicitly carries the `_optional` suffix. Input objects are immutable for the duration of the call. Output objects belong to the caller, are fully initialized on every return after argument validation, and contain no borrowed internal pointer unless their type explicitly states its lifetime. An indexed function shall validate the index before acquiring the command lock or accessing the device.

`API-HDR-005` — A state-changing API shall require a non-null `dfc_command_result_t *`; callers shall not be permitted to discard ambiguity, partial completion, or retry disposition accidentally.

`API-HDR-006` — Each public header shall document blocking behavior, lifecycle states, permitted calling contexts, lock acquisition, side effects, and whether output is valid for every returned `dfc_status_t`.

# 9. Common Type Definitions

## 9.1 Fundamental Types

| Type | Contract |
|---|---|
| `dfc_device_t` | Opaque live device context; never copied |
| `dfc_deadline_t` | Absolute BSP-monotonic deadline in microseconds |
| `dfc_duration_us_t` | Unsigned duration in microseconds with checked arithmetic |
| `dfc_reg_id_t` | Generated logical register identifier; not an unchecked byte address |
| `dfc_field_id_t` | Generated logical field identifier |
| `dfc_operation_id_t` | Monotonic software operation identity scoped to one lifecycle generation |
| `dfc_lifecycle_generation_t` | Increments on each successful construction/recovery epoch |
| `dfc_raw_timestamp_t` | Device raw microsecond timestamp represented as `uint64_t` |
| `dfc_signed_offset_us_t` | Signed 64-bit correlation offset in microseconds |

## 9.2 Public Storage

`DFC_DEVICE_STORAGE_SIZE` and `DFC_DEVICE_STORAGE_ALIGN` shall define the storage required for one context in a specific API major version and target profile. A caller may provide statically allocated, correctly aligned storage. The library shall not require dynamic allocation for steady-state embedded operation.

## 9.3 Observation Rules

`API-TYPE-001` — Observation structures shall distinguish current state, sticky evidence, counters, pending state, staged state, active state, requested state, commanded state, effective state, terminal result, cached value, and derived value.

`API-TYPE-002` — Every cached observation shall carry lifecycle generation, host acquisition time, and freshness classification.

`API-TYPE-003` — Device event records and canonical messages shall use generated encode/decode accessors; a host structure shall not be overlaid on returned bytes.

# 10. Status and Error Code Model

## 10.1 Software Status

`dfc_status_t` shall include at least the following stable semantic classes:

| Status | Meaning |
|---|---|
| `DFC_STATUS_OK` | Requested software operation completed and its required postconditions hold |
| `DFC_STATUS_INVALID_ARGUMENT` | Caller input failed software validation |
| `DFC_STATUS_NOT_INITIALIZED` | Context is not in a state permitting the operation |
| `DFC_STATUS_BUSY` | Local coordinator or device resource cannot currently admit the operation |
| `DFC_STATUS_DEADLINE_EXPIRED` | Caller deadline expired before a definitive completion |
| `DFC_STATUS_TRANSPORT_ERROR` | BSP or SPI-controller failure occurred |
| `DFC_STATUS_PROTOCOL_ERROR` | Response framing, marker, length, reserved field, status, or CRC was invalid |
| `DFC_STATUS_DEVICE_REJECTED` | Device returned a definitive non-success status |
| `DFC_STATUS_AMBIGUOUS` | A state-changing operation lacks a safe definitive classification |
| `DFC_STATUS_INCOMPATIBLE` | Product, register map, capability, or binding is unsupported |
| `DFC_STATUS_NO_DATA` | Requested nondestructive observation has no current data |
| `DFC_STATUS_RESOURCE_EXHAUSTED` | Caller-supplied or software-owned bounded resource is unavailable |
| `DFC_STATUS_CONTEXT_ERROR` | Operation is prohibited in the current thread, callback, ISR, or lifecycle context |
| `DFC_STATUS_INTERNAL_ERROR` | Software invariant failed |

## 10.2 Command Result

Every state-changing public API shall return `dfc_status_t` and populate a required caller-supplied `dfc_command_result_t` with:

- operation ID and lifecycle generation;
- local admission and validation status;
- BSP/platform result and actual transferred extent;
- response-integrity classification;
- definitive SPI status when received;
- completed-word count;
- final DRI endpoint code when obtained through reconciliation or mapped diagnostics;
- outcome classification: no effect proven, complete, partial, rejected, ambiguous, or indeterminate;
- reconciliation classification and terminal-record snapshot when performed;
- applicable active readback or a reference to it; and
- retry disposition: prohibited, safe, caller-policy decision, or not applicable.

`API-STS-001` — A Boolean value alone is insufficient for a state-changing result.

`API-STS-002` — Partial completion is not success and shall preserve the exact completed extent.

`API-STS-003` — A local timeout does not prove that a device-side effect did not occur.

`API-STS-004` — The original device status and raw transport classification shall remain available after mapping to `dfc_status_t`.

# 11. Version Identification API

## 11.1 Public Functions

| Function | Contract |
|---|---|
| `dfc_api_version(void)` | Return compile-time API semantic version |
| `dfc_implementation_version(void)` | Return library build and source identity |
| `dfc_binding_manifest(void)` | Return immutable generated-binding identity and supported register-map range |
| `dfc_device_identity(dfc_device_t *, dfc_device_identity_t *)` | Return discovered product, revision, capability, register-map, and device-build identity |
| `dfc_device_compatibility(dfc_device_t *, dfc_compatibility_t *)` | Return the recorded compatibility decision and reason |

`API-VER-001` — Discovery shall compare independent version axes and shall not infer compatibility from product name, build date, FPGA platform, or filename.

`API-VER-002` — A breaking public API or ABI change requires a major version change; a compatible addition requires a minor change; a behavior-preserving correction requires a patch change.

# 12. Compile-Time Configuration Model

## 12.1 Permitted Options

Compile-time options may select logging, assertions, engineering raw access, callback capacity, software queue capacity, static storage profile, and supported BSP implementation. They shall not select alternate device behavior or remove handling for a device result possible under the controlling contract.

## 12.2 Rules

`API-CFGC-001` — Every compile-time option affecting behavior, size, ABI, diagnostics, or verification shall appear in the build manifest.

`API-CFGC-002` — Production builds shall disable raw register writes, simulator backdoors, wrapper-private access, software fault injection, and unrestricted engineering hooks by default.

`API-CFGC-003` — Conditional compilation shall not change public structure layout within one declared ABI profile.

`API-CFGC-004` — The portable driver shall compile with no operating-system dependency and no mandatory heap dependency.

# 13. BSP Interface Requirements

## 13.1 BSP Operation Table

The caller shall supply an immutable `dfc_bsp_ops_t` and a platform context. The operation table shall contain:

| Operation | Required behavior |
|---|---|
| `spi_transaction` | Execute one complete command/response exchange under one continuous asserted chip-select interval, obey host-side SRS timing, clock response bytes after the command, and report actual captured bytes and platform status |
| `irq_register` | Register one bounded host-interrupt top-half callback |
| `irq_mask` / `irq_unmask` | Control the host interrupt receiver without changing Dragon Core interrupt state |
| `irq_ack_host` | Acknowledge only the host interrupt controller when required by the platform |
| `monotonic_now_us` | Return nondecreasing external-host monotonic time |
| `wait_until` | Optionally block or yield until a deadline or notification |
| `lock` / `unlock` | Provide mutual exclusion with declared nesting and priority behavior |
| `memory_barrier` | Enforce host-side ordering required by the controller and shared callback state |
| `secure_zero` | Clear sensitive external-host temporary storage when used |
| `log_record` | Optionally accept structured, bounded, nonblocking software diagnostic records |

## 13.2 BSP Contract

`API-BSP-001` — `spi_transaction` shall never deassert chip select between command and response and shall not split one Dragon Core command across controller transactions.

`API-BSP-002` — The BSP shall report the number of captured response bytes actually transferred. A short transfer is not success.

`API-BSP-003` — The BSP shall not interpret a Dragon Core response or retry a transaction.

`API-BSP-004` — The SPI implementation shall support every SRS-permitted frame length and wait-fill extent required by the enabled API.

`API-BSP-005` — The BSP shall define whether an expired deadline can cancel a controller operation and whether cancellation may leave chip select asserted; the driver shall treat uncertain termination as ambiguous for state-changing commands.

`API-BSP-006` — BSP callbacks shall not call the portable driver recursively.

`API-BSP-007` — Missing required operations or incompatible BSP capability declarations shall cause construction to fail before device access.

# 14. VisionFive 2/ECP5 Validation-Host BSP Interface

The validation BSP shall adapt the selected VisionFive 2 SPI controller and interrupt receiver to `dfc_bsp_ops_t`. It shall expose no ECP5 wrapper-private behavior to the portable driver.

`API-VF-001` — The validation BSP shall demonstrate the full SRS-defined SPI frequency range used by verification, continuous chip-select behavior, exact bit and byte order, actual-length reporting, and deadline behavior.

`API-VF-002` — Validation-only instrumentation shall be compile-time isolated, explicitly labeled, and absent from production BSP builds.

`API-VF-003` — Host cache maintenance, DMA descriptors, controller FIFOs, and memory barriers are BSP responsibilities and shall be verified with short, maximum-length, wait-fill, response-truncation, and concurrent-interrupt cases.

# 15. Production External-Host BSP Interface

The production BSP is implemented for a processor and SPI controller outside the fabricated ASIC. No portion of it executes in Dragon Core or OpenFrame.

`API-PROD-001` — A production BSP shall preserve the same `dfc_bsp_ops_t` semantics and the same logical driver behavior used in FPGA validation.

`API-PROD-002` — The production BSP shall document controller mode, clock tolerance, chip-select implementation, interrupt polarity and sensitivity, DMA/cache behavior, locking, deadline resolution, cancellation behavior, and reset coordination.

`API-PROD-003` — A production host that cannot preserve continuous chip select or required timing for one command/response exchange is incompatible and shall be rejected at integration.

`API-PROD-004` — Platform project-identification resources, OpenFrame metadata, scan paths, and wrapper-private signals shall not be used as device-control or compatibility paths.

# 16. SPI Transport Primitive API

## 16.1 Internal Portable Interface

The SPI transport primitive is private to the driver and shall expose this semantic operation:

| Operation | Inputs | Outputs |
|---|---|---|
| `dfc_transport_execute` | Context, immutable encoded command, expected response bounds, absolute deadline | Raw captured bytes, actual length, BSP result, timing evidence, and transfer-termination classification |

## 16.2 Rules

`API-SPI-001` — Command and response serialization shall consume `DFC-INTF-0011` through `DFC-INTF-0036` and generated constants; this specification does not restate their numeric encoding.

`API-SPI-002` — CRC shall be computed over explicit bytes with a separately verified implementation and known-answer tests.

`API-SPI-003` — Response parsing shall validate actual length, wait-fill bound, marker, reserved byte, transmitted status range, completed-word count, read-data extent, and CRC before returning a definitive result.

`API-SPI-004` — Writes shall never infer success from byte transfer completion alone.

`API-SPI-005` — Reads shall return only the words covered by the validated completed-word count and response CRC.

`API-SPI-006` — Multiword execution is ordered and non-atomic as controlled by the SRS and Architecture. The driver shall not synthesize rollback.

## 16.3 Ambiguous-Outcome Reconciliation API

| Function | Contract |
|---|---|
| `dfc_reconcile_last_transaction(dfc_device_t *, const dfc_ambiguous_operation_t *, dfc_deadline_t, dfc_reconciliation_result_t *)` | Under exclusive command ownership, read the complete coherent terminal host-reconciliation record through the generated Register Map workflow, compare it with the retained ambiguous operation, obtain required target readback, and classify the outcome |

Reconciliation shall classify an operation as complete, partially complete, definitively rejected before effect, not represented by the terminal record, superseded, or indeterminate. A sequence/opcode/address match alone is insufficient when completed extent, terminal status, target state, or lifecycle generation does not match.

`API-REC-001` — The driver shall retain the encoded command identity, operation ID, expected target effects, submission phase, captured raw response bytes, and BSP termination classification until reconciliation completes or the context is destroyed.

`API-REC-002` — The coherent reconciliation read shall use generated Register Map definitions and the controlling response-local snapshot procedure; it shall not be assembled from separately interleaved reads.

`API-REC-003` — Reset, push, pop, clear, acknowledge, commit, service, recovery, and other non-idempotent operations shall not be retried unless reconciliation and required active readback prove that duplication is impossible.

`API-REC-004` — If another accepted command may have superseded the terminal record before it is read, the original operation remains indeterminate unless target readback proves its outcome.

# 17. Memory Barrier and Ordering API

`dfc_bsp_memory_barrier()` shall provide the host ordering required before and after SPI controller ownership changes, DMA completion, interrupt-state publication, and cross-context queue publication.

`API-ORD-001` — Barriers apply only to external-host memory and controller interaction. They shall not be described as ordering Dragon Core register side effects beyond the controlling transaction contract.

`API-ORD-002` — Portable code shall call the BSP ordering primitive only at declared ownership boundaries; arbitrary use shall not substitute for locks or protocol completion.

# 18. Critical Section and Locking API

## 18.1 Lock Classes

| Lock | Protects | Restrictions |
|---|---|---|
| Context lock | Lifecycle state, callback registry, cached observations | Shall not be held while invoking application callbacks |
| Command lock | Complete SPI command stream and dependent workflow | One owner; no recursive device calls |
| Service lock | Deferred interrupt/event service scheduling state | May be acquired in top half only if BSP declares bounded ISR-safe behavior |

## 18.2 Rules

`API-LOCK-001` — Lock order shall be context, command, then service when more than one is required.

`API-LOCK-002` — Protected-write sequences, selector-dependent reads, snapshot/pop workflows, staged commits, and reconciliation workflows shall retain exclusive command ownership across every operation whose interleaving could invalidate the workflow.

`API-LOCK-003` — A caller deadline shall include lock wait, transport, device completion, readback, and reconciliation time.

`API-LOCK-004` — Lock failure or deadline expiry before command submission proves no device effect; expiry after uncertain submission does not.

# 19. Host Interrupt Primitive API

## 19.1 BSP Top Half

The registered BSP top half shall mask or acknowledge only the external host interrupt controller as required, atomically schedule deferred device service, and return. It shall not perform SPI, clear Dragon Core evidence, pop events, service the watchdog, or invoke application callbacks.

## 19.2 Public Functions

| Function | Contract |
|---|---|
| `dfc_interrupt_service_request(dfc_device_t *)` | Schedule deferred interrupt processing; callable from the BSP top half |
| `dfc_interrupt_service(dfc_device_t *, dfc_deadline_t, dfc_interrupt_report_t *)` | Read pending and raw state, dispatch bounded deferred notifications, perform only policy-authorized acknowledge or clear operations, and report remaining pending state |

`API-HIRQ-001` — Host-controller acknowledgement and Dragon Core interrupt acknowledgement or clear are independent operations.

`API-HIRQ-002` — Level-sensitive host interrupt service shall recheck device pending state before host unmask to avoid a lost level transition.

# 20. Timing and Deadline Primitive API

| Function | Contract |
|---|---|
| `dfc_deadline_from_now(dfc_device_t *, dfc_duration_us_t, dfc_deadline_t *)` | Create an absolute deadline using checked addition |
| `dfc_deadline_remaining(dfc_device_t *, dfc_deadline_t, dfc_duration_us_t *)` | Return bounded remaining time without wall-clock use |
| `dfc_wait_until(dfc_device_t *, dfc_deadline_t)` | Invoke BSP wait/yield without device access |

`API-TIME-001` — All public blocking or polling APIs shall accept an absolute deadline or use a documented nonblocking form.

`API-TIME-002` — Software deadlines shall use the external-host monotonic clock and shall remain distinct from the Dragon Core raw and correlated timestamps.

`API-TIME-003` — Zero and already-expired deadlines shall produce deterministic nonblocking behavior.

# 21. HAL Initialization Model

## 21.1 Public Lifecycle API

| Function | Contract |
|---|---|
| `dfc_device_construct(void *storage, size_t storage_size, const dfc_bsp_ops_t *, void *bsp_context, const dfc_device_options_t *, dfc_device_t **)` | Validate storage, BSP, options, and construct an unopened context without device access |
| `dfc_device_open(dfc_device_t *, dfc_deadline_t, dfc_open_report_t *)` | Establish transport readiness, discover identity, validate compatibility, capture baseline status, and enter OPEN or RECOVERY_REQUIRED |
| `dfc_device_close(dfc_device_t *, dfc_deadline_t)` | Stop new work, mask host interrupt, drain or terminate software work, and enter CLOSED without assuming device reset |
| `dfc_device_destroy(dfc_device_t *)` | Release software-owned state after close; never access the device |
| `dfc_device_recover(dfc_device_t *, const dfc_recovery_options_t *, dfc_deadline_t, dfc_recovery_report_t *)` | Re-establish transport, rediscover identity, reconcile or invalidate outstanding work, refresh active state, and hand configuration reapplication to the caller |

## 21.2 Lifecycle States

`UNCONSTRUCTED`, `CLOSED`, `OPENING`, `OPEN`, `RECOVERY_REQUIRED`, `CLOSING`, and `FAILED` are software-only states. They do not redefine Dragon Core operating state.

`API-LIFE-001` — Every public function shall declare the permitted lifecycle states.

`API-LIFE-002` — Reset, reconnect, identity change, incompatible register-map change, or unresolved ambiguity shall invalidate cached observations and increment lifecycle generation after successful recovery.

`API-LIFE-003` — Opening shall not assert operational enable or apply installation configuration implicitly.

# 22. Device Discovery and Compatibility Model

## 22.1 Discovery Sequence

Discovery shall use typed reads of Register-Map-owned identification, product revision, register-map revision, build identity, capability, host readiness, and system status. The driver shall then select an exact generated-binding compatibility profile.

## 22.2 Public Functions

| Function | Contract |
|---|---|
| `dfc_device_refresh_identity(dfc_device_t *, dfc_deadline_t, dfc_device_identity_t *)` | Re-read identity and invalidate the context on an unexpected change |
| `dfc_device_get_capabilities(dfc_device_t *, dfc_capabilities_t *)` | Return immutable discovered capabilities for the current lifecycle generation |
| `dfc_device_get_state(dfc_device_t *, dfc_deadline_t, dfc_device_state_t *)` | Return typed current device state and orthogonal readiness qualifiers |
| `dfc_device_set_operational_enable(dfc_device_t *, bool, dfc_deadline_t, dfc_command_result_t *)` | Perform the protected typed update, return exact result, and read back independent effective-operational-enable and system-state qualifiers |

`API-DISC-001` — Discovery shall reject an unknown product identity, unsupported register-map major version, impossible capability combination, or binding-manifest mismatch.

`API-DISC-002` — Forward-compatible minor support is permitted only when the binding manifest explicitly declares it and all accessed fields retain defined semantics.

# 23. Register Access API

## 23.1 Production Typed Access

Production code shall use generated typed accessors or module APIs. The following generated primitives may be used internally:

| Function family | Contract |
|---|---|
| `dfc_reg_read32` | Read one generated readable 32-bit register through the command coordinator |
| `dfc_reg_write32` | Write one generated writable 32-bit register after host-side access, reserved-bit, and encoding validation |
| `dfc_reg_read_block` | Read one to the controlling maximum sequential words and preserve partial completion |
| `dfc_reg_write_block` | Write one to the controlling maximum sequential words and preserve ordered non-atomic completion |
| `dfc_reg_protected_write32` | Under exclusive command ownership, perform the generated two-key authorization sequence followed by exactly one permitted protected write and return the target result/readback |

## 23.2 Access Rules

`API-REG-001` — Byte, halfword, unaligned, direct-MMIO, memory-mapped pointer, and host-structure overlay APIs are prohibited.

`API-REG-002` — Read-modify-write is not a primitive. A typed helper may perform read/compose/write only when the Register Map permits the resulting full-word write and concurrent hardware change cannot be lost.

`API-REG-003` — W1C, W1S, WO-CMD, COUNTER-CLR, COUNTER16-CLR, CONST, CONST1, RSV0, RW, and RO semantics shall use distinct generated metadata and typed helpers.

`API-REG-004` — A read is nondestructive unless the selected Register Map contract explicitly defines the read side effect. Snapshot and pop shall remain explicit commands.

`API-REG-005` — No host-visible API shall expose centralized shared-buffer physical addresses; queues and mailboxes are accessed through their register-defined proxy workflows.

`API-REG-006` — Protected authorization shall never be cached, shared across callers, reused for a later write, or restored after an error. Failure of either key or the target operation terminates the workflow and is reported exactly.

`API-REG-007` — Key writes and the protected target write shall remain noninterleaved. A transport ambiguity during any member transitions the context to reconciliation or recovery; the library shall not emit another key sequence until the prior state is safely classified.

# 24. Configuration Workflow API

## 24.1 Configuration Object

`dfc_configuration_t` is a software-owned desired-configuration object. It shall carry schema version, target identity constraints, field-presence information, values in exact device units, and external policy metadata kept separate from device fields.

## 24.2 Public Functions

| Function | Contract |
|---|---|
| `dfc_configuration_validate` | Validate schema, target compatibility, cross-object software policy, generated field constraints, and required presence without device access |
| `dfc_configuration_read_active` | Read a complete active configuration view using selector-safe workflows |
| `dfc_configuration_plan` | Produce an ordered, bounded, reviewable change plan with protected and commit groups explicit |
| `dfc_configuration_apply` | Execute a supplied plan, stop on first failure, reconcile ambiguity, and read back every changed active object |
| `dfc_configuration_compare` | Compare desired versus active state and report exact differences without modifying the device |

`API-CFG-001` — Applying configuration shall not clear unrelated sticky evidence, counters, interrupts, events, queues, or reconciliation state.

`API-CFG-002` — Staged objects shall follow select, complete stage, validate/commit, terminal-result read, and active-readback steps under exclusive command ownership.

`API-CFG-003` — A failed or ambiguous plan shall report the last definitive completed step, any partial completion, the first unresolved step, and active readback obtained.

`API-CFG-004` — Nondefault volatile configuration shall be stored and reapplied by the external host owner; the driver shall not presume retention across reset or power loss.

# 25. Interrupt Controller API

| Function | Contract |
|---|---|
| `dfc_irq_read(dfc_device_t *, dfc_deadline_t, dfc_irq_state_t *)` | Read coherent raw, enabled, pending, primary, and aggregate interrupt state |
| `dfc_irq_set_enable(dfc_device_t *, dfc_irq_mask_t, dfc_deadline_t, dfc_command_result_t *)` | Set the complete legal enable mask through its typed register contract |
| `dfc_irq_acknowledge(dfc_device_t *, dfc_irq_mask_t, dfc_deadline_t, dfc_command_result_t *)` | Issue only the Register-Map-defined acknowledgement operation |
| `dfc_irq_clear(dfc_device_t *, dfc_irq_mask_t, dfc_deadline_t, dfc_command_result_t *)` | Issue only the Register-Map-defined clear operation |

`API-IRQ-001` — Acknowledge, clear, disable, raw-source disappearance, sticky-evidence clear, fault clear, and event pop are distinct operations.

`API-IRQ-002` — Reserved source positions shall be rejected by host-side validation and never written as one.

`API-IRQ-003` — Service shall iterate to a bounded policy limit and report remaining pending sources rather than spin indefinitely.

# 26. Event Logger API

| Function | Contract |
|---|---|
| `dfc_event_read_status` | Read occupancy, empty/full, overflow, drop, and applicable counter state |
| `dfc_event_snapshot_oldest` | Explicitly capture the oldest retained record without removing it |
| `dfc_event_read_snapshot` | Read and decode the complete captured record; nondestructive |
| `dfc_event_pop_snapshot` | Remove only the record associated with the valid snapshot according to the Register Map contract |
| `dfc_event_drain` | Repeatedly snapshot, validate, hand off, and pop under a caller-provided bounded record count and deadline |
| `dfc_event_clear_store` | Issue the explicit store-clear command when caller policy permits |

`API-EVT-001` — The software shall preserve the raw 128-bit event record and separately expose decoded fields.

`API-EVT-002` — A record shall be popped only after the caller's handoff callback or destination confirms acceptance, unless the caller explicitly selects discard policy.

`API-EVT-003` — Retrieval shall report device overflow/drop evidence and software-side handoff loss independently.

`API-EVT-004` — Event timestamps are raw device timestamps; host receipt time and optional correlated presentation are separate metadata.

# 27. Timestamp API

| Function | Contract |
|---|---|
| `dfc_timestamp_read_raw` | Use the Register-Map-defined coherent snapshot workflow and return raw microseconds |
| `dfc_timestamp_read_correlated` | Return the defined correlated presentation without altering raw time |
| `dfc_timestamp_read_offset` | Read the complete active signed correlation offset |
| `dfc_timestamp_set_offset` | Stage both words, perform protected commit, read terminal status, and read back the active offset |
| `dfc_timestamp_observe` | Return device raw time, correlated time, host monotonic acquisition time, and uncertainty metadata |

`API-TS-001` — Software shall never write, reset, stop, or emulate the raw device timestamp.

`API-TS-002` — Signed offset arithmetic shall be checked and shall preserve the controlling two's-complement semantics.

# 28. GPIO API

| Function | Contract |
|---|---|
| `dfc_gpio_read` | Return synchronized/qualified input, commanded output, effective output, direction, configuration, and evidence as distinct fields |
| `dfc_gpio_configure` | Apply legal per-channel direction, qualification, event, and interrupt configuration and read back active state |
| `dfc_gpio_write` | Update only output-command fields for channels configured and permitted as outputs |
| `dfc_gpio_clear_evidence` | Clear only selected GPIO sticky evidence through typed W1C operations |

`API-GPIO-001` — Toggle shall not be a public primitive because a software read followed by write is not an atomic hardware operation.

`API-GPIO-002` — Input state, commanded output, effective output, and external pad level shall not be conflated.

# 29. Rotor RPM API

| Function | Contract |
|---|---|
| `dfc_rotor_configure` | Apply legal enable, pulse-per-revolution, thresholds, timeout, qualification, hysteresis, event, and interrupt configuration |
| `dfc_rotor_read` | Return current RPM, period, validity, timeout, threshold state, sticky evidence, and configuration readback |
| `dfc_rotor_clear_evidence` | Clear only selected retained evidence |

`API-ROTOR-001` — The API shall return hardware-reported integer RPM and period values without inventing averaging, filtering, or calibration absent from the controlling contract.

# 30. Engine RPM API

| Function | Contract |
|---|---|
| `dfc_engine_configure` | Apply legal engine-monitor configuration and read it back |
| `dfc_engine_read` | Return current RPM, period, validity, timeout, threshold state, sticky evidence, and configuration readback |
| `dfc_engine_clear_evidence` | Clear only selected retained evidence |

`API-ENGINE-001` — Rotor and engine contexts, limits, status, and evidence shall remain separate even when their software structures share a common representation.

# 31. Pulse/Frequency Measurement API

| Function | Contract |
|---|---|
| `dfc_pulse_configure` | Apply legal configuration for the selected hardware channel and read it back |
| `dfc_pulse_read` | Return exact Q17.15 frequency, period, validity, timeout, threshold, and evidence state |
| `dfc_pulse_frequency_to_double` | Optional presentation helper outside safety decisions; convert Q17.15 without changing the raw value |
| `dfc_pulse_clear_evidence` | Clear only selected channel evidence |

`API-PULSE-001` — The raw Q17.15 value shall remain available and authoritative; floating-point presentation shall be explicitly derived.

`API-PULSE-002` — Channel indices shall be range checked before any register selection.

# 32. Sensor Monitor API

| Function | Contract |
|---|---|
| `dfc_sensor_configure` | Apply legal per-channel thresholds, hysteresis, maximum age, and event/interrupt configuration |
| `dfc_sensor_commit_sample` | Stage value and complete metadata, commit atomically through the defined host workflow, and return acceptance/readback |
| `dfc_sensor_read` | Return signed value, source, sequence, age, validity, stale, thresholds, evidence, and active configuration |
| `dfc_sensor_clear_evidence` | Clear only selected retained evidence |

`API-SENSOR-001` — Analog acquisition, calibration, engineering-unit conversion, and calibration persistence remain external and shall not be represented as Dragon Core services.

`API-SENSOR-002` — Signed comparisons and conversion shall preserve exact 32-bit two's-complement values.

`API-SENSOR-003` — Host update rejection or loss to an authorized routed update shall be reported without software reconstructing an unobserved device ordering.

# 33. System Health Monitor API

| Function | Contract |
|---|---|
| `dfc_health_configure` | Apply legal polarity, qualification, fault, event, and interrupt configuration and read it back |
| `dfc_health_read` | Return raw, synchronized, qualification-in-progress, qualification-failure, active, sticky, recovery, and aggregate state distinctly |
| `dfc_health_clear_evidence` | Clear only selected retained evidence |

`API-HEALTH-001` — Health acknowledgement shall not be presented as clearing an active external condition.

`API-HEALTH-002` — External semantic meaning assigned to each health input remains application configuration and shall not alter the raw device observation.

# 34. Watchdog API

| Function | Contract |
|---|---|
| `dfc_watchdog_configure` | Perform the required protected configuration workflow and read back active timing and response configuration |
| `dfc_watchdog_read` | Return enabled state, elapsed time, window state, active/sticky timeout and service evidence, and active configuration |
| `dfc_watchdog_service` | Validate caller service policy, issue the exact service command once, and return definitive or reconciled outcome |
| `dfc_watchdog_recover` | Issue only the defined recovery operation and return result/readback |
| `dfc_watchdog_clear_evidence` | Clear only selected retained evidence |

`API-WDOG-001` — A service operation shall never be blindly retried after timeout, transport error, truncated response, invalid response, or other ambiguous completion.

`API-WDOG-002` — Driver scheduling shall expose the legal service window to external firmware policy but shall not claim that software service replaces hardware timeout enforcement.

# 35. Fault Manager API

| Function | Contract |
|---|---|
| `dfc_fault_configure` | Apply legal enable/class/response configuration through protected workflows and read back active state |
| `dfc_fault_read` | Return active and latched source masks, primary source, class, response, degraded state, recoverability, and evidence |
| `dfc_fault_clear_latched` | Clear only selected recoverable latched sources through the defined command |
| `dfc_fault_clear_evidence` | Clear only selected diagnostic evidence independent of fault latches |

`API-FAULT-001` — The production API shall not provide a software-fault-report function that fabricates a hardware fault source.

`API-FAULT-002` — Source numbers and recoverability shall come from generated Architecture/Register-Map bindings and shall not be copied into hand-authored enums.

# 36. Interlock Engine API

| Function | Contract |
|---|---|
| `dfc_interlock_read_bank` | Read all active entries and current/latched result state |
| `dfc_interlock_stage_bank` | Stage a complete eight-entry software object under exclusive command ownership |
| `dfc_interlock_commit_bank` | Perform the complete-bank validate/commit operation once, read terminal status, and read back all active entries |
| `dfc_interlock_clear_evidence` | Clear only selected retained violation or diagnostic evidence |

`API-ILOCK-001` — Partial-bank activation is prohibited. A software object shall be validated as a complete bank before staging.

`API-ILOCK-002` — Interlock term, operator, guard, response, and enable encodings shall be generated from the controlling definitions.

# 37. Lost-Link Supervisor API

| Function | Contract |
|---|---|
| `dfc_lost_link_configure` | Apply legal selected-monitor source, qualification, timeout, recovery, response, event, and interrupt configuration |
| `dfc_lost_link_read` | Return per-monitor active, sticky, elapsed, source, recovery, and configuration state |
| `dfc_lost_link_clear_evidence` | Clear only selected retained evidence |

`API-LLINK-001` — Software-generated activity injection, if exposed at all, shall be engineering/test-profile only and shall require the controlling authorization state.

# 38. Safety Output API

| Function | Contract |
|---|---|
| `dfc_safety_output_configure` | Apply protected per-channel enable, polarity, latch, response, and interlock configuration and read back active state |
| `dfc_safety_output_read` | Return requested, latched, commanded, effective, inhibited, cause, reset-held, and active-configuration state distinctly |

`API-SAFEOUT-001` — A logical safety output is not an aircraft-energy output. External drive circuitry and installation policy remain outside the API contract.

`API-SAFEOUT-002` — Software shall never report a requested or commanded state as effective without reading the independent effective and inhibit/cause state.

# 39. ARINC 429 API

| Function | Contract |
|---|---|
| `dfc_arinc_rx_configure` | Apply legal receive speed, parity acceptance, event, and interrupt configuration |
| `dfc_arinc_rx_read_status` | Return occupancy, full/empty, adapter and protocol evidence, and counters |
| `dfc_arinc_rx_snapshot` | Capture the next complete receive entry without removal |
| `dfc_arinc_rx_read_snapshot` | Return exact word, metadata, raw timestamp, and evidence from the snapshot |
| `dfc_arinc_rx_pop` | Remove only the valid captured entry |
| `dfc_arinc_tx_configure` | Apply legal transmit speed, gap, parity, event, and interrupt configuration |
| `dfc_arinc_tx_push` | Stage a complete transmit entry, push exactly once, and return definitive/reconciled outcome |
| `dfc_arinc_tx_read_status` | Return queue, timing, rejection, adapter, and protocol evidence |

`API-ARINC-001` — ARINC electrical line reception and drive remain external. The API handles only the defined digital contract.

`API-ARINC-002` — Receive snapshot and pop, and transmit stage and push, shall remain separate explicit operations.

# 40. Classical CAN API

| Function | Contract |
|---|---|
| `dfc_can_configure` | Apply legal bit timing, operating mode, event, and interrupt configuration and read it back |
| `dfc_can_read_status` | Return controller state, bus-off/error state, RX/TX occupancy, evidence, and counters |
| `dfc_can_rx_snapshot` | Capture one complete receive frame without removal |
| `dfc_can_rx_read_snapshot` | Return exact identifier, IDE, RTR, DLC, data, raw timestamp, and metadata |
| `dfc_can_rx_pop` | Remove only the valid captured frame |
| `dfc_can_tx_push` | Stage a complete legal frame, push once, and return definitive/reconciled outcome |
| `dfc_can_recover` | Issue only the defined bus recovery operation and report resulting state |

`API-CAN-001` — The API shall reject impossible identifier, DLC, RTR/data, or timing combinations before submission while retaining device enforcement as authoritative.

`API-CAN-002` — The API shall not claim hardware acceptance filtering not present in the controlling contract.

# 41. UART API

| Function | Contract |
|---|---|
| `dfc_uart_configure` | Apply legal divisor, parity, enable, event, and interrupt configuration and read it back |
| `dfc_uart_read_status` | Return RX/TX occupancy, empty/full, current error, sticky evidence, and counters |
| `dfc_uart_rx_read` | Read the next byte and its defined metadata without removal when a snapshot is required |
| `dfc_uart_rx_pop` | Remove exactly one available receive byte |
| `dfc_uart_tx_push` | Push exactly one byte and return definitive/reconciled outcome |

`API-UART-001` — Multi-byte transmit and receive convenience functions shall loop over one-byte device operations, accept a caller deadline, return exact completed extent, and never imply device-side atomicity.

`API-UART-002` — Baud rate is a derived presentation; the programmed divisor and actual configured result shall remain available.

# 42. Databus Routing API

| Function | Contract |
|---|---|
| `dfc_route_read_bank` | Read all active route entries and routing status/counters |
| `dfc_route_stage_bank` | Validate and stage a complete sixteen-entry route bank |
| `dfc_route_commit_bank` | Commit once, read terminal result, and read back the complete active bank |
| `dfc_route_read_losses` | Return ingress and destination loss counters without clearing them |
| `dfc_route_clear_losses` | Clear only selected whole counters through typed counter-clear operations |

`API-ROUTE-001` — Source, destination, type, filter, authorization, and route-count definitions shall come from generated controlling bindings.

`API-ROUTE-002` — Adding or removing one route is a software transformation of a complete desired bank followed by complete-bank staging and commit; it is not a direct hardware add/remove primitive.

# 43. Mask-Defined User Logic API

Revision A mask-defined user logic is inert for operational function. The production API shall expose identity/status observation and only the diagnostic mailbox operations permitted by the controlling contract.

| Function | Contract |
|---|---|
| `dfc_user_logic_read` | Return inert-profile status, fixed parameters, I/O state, mailbox state, evidence, and counters |
| `dfc_user_logic_mailbox_push` | Push one diagnostic mailbox entry when permitted and return definitive/reconciled result |
| `dfc_user_logic_mailbox_pop` | Pop one diagnostic mailbox entry through the defined workflow |

`API-ULI-001` — Functions that enable execution, program logic, request operational output, or create operational messages are prohibited in Revision A.

`API-ULI-002` — Nonzero functional parameters or output requests shall not be normalized to zero and submitted; they shall be rejected by host-side validation.

# 44. User-Configurable Routing API

| Function | Contract |
|---|---|
| `dfc_user_route_read_bank` | Read every active entry and current routing status |
| `dfc_user_route_stage_bank` | Validate and stage the complete user-route bank |
| `dfc_user_route_commit_bank` | Commit once, read terminal result, and read back the complete active bank |
| `dfc_user_route_clear_evidence` | Clear only selected retained evidence |

`API-UROUTE-001` — Source, destination, mode, exclusivity, and authorization matrices shall come from generated controlling bindings.

`API-UROUTE-002` — User routing configures finite predefined signal connections only; it shall not be described or exposed as field-programmable logic.

# 45. Driver Layer Responsibilities

The portable driver shall own:

- context validation and lifecycle enforcement;
- one serialized command stream per context;
- explicit wire encoding and response validation;
- host-known access and value validation;
- protected authorization sequencing;
- selector, snapshot, staging, commit, and proxy workflows;
- typed clear, acknowledge, service, reset, push, pop, and recovery operations;
- exact partial-completion reporting;
- ambiguous-outcome reconciliation and readback;
- cache invalidation and lifecycle generation;
- bounded deferred notifications; and
- structured software diagnostics.

`API-DRV-001` — Device enforcement remains authoritative even when the driver rejects known-invalid input first.

`API-DRV-002` — The driver shall not cache volatile device configuration as authoritative across reset, recovery, or ambiguity.

`API-DRV-003` — Every side-effecting helper shall state its register interactions, interleaving boundary, retry rule, deadline behavior, and required post-operation readback.

# 46. Driver/HAL Boundary Rules

| Boundary | Driver responsibility | HAL/BSP responsibility |
|---|---|---|
| SPI | Encode, size, parse, validate, classify | Controller setup, continuous CS, clocking, actual length, platform error |
| Interrupt | Read and service device sources | Receive, mask, acknowledge, and defer host interrupt |
| Time | Deadline arithmetic and operation policy | Monotonic source and wait/yield |
| Concurrency | Workflow ownership and lock order | Lock implementation and memory ordering |
| Diagnostics | Semantic record and redaction class | Bounded output sink |

`API-BOUND-001` — A platform failure shall remain distinguishable from a device rejection and protocol-integrity failure.

`API-BOUND-002` — The BSP shall not automatically repeat a controller transfer; the driver is the sole owner of retry admission.

`API-BOUND-003` — Driver tests shall run against a deterministic BSP test double without requiring FPGA or ASIC hardware.

# 47. Callback and Notification Model

## 47.1 Public Functions

| Function | Contract |
|---|---|
| `dfc_callback_register` | Register one callback, immutable user context, event mask, priority class, and execution policy in caller-supplied bounded capacity |
| `dfc_callback_unregister` | Prevent future dispatch and define whether an in-progress callback may complete |
| `dfc_dispatch` | Deliver queued immutable observations in deferred software context up to a caller-supplied bound and deadline |

## 47.2 Rules

`API-CB-001` — Callbacks shall receive immutable copies or borrowed observations with explicit lifetime valid only for the call.

`API-CB-002` — The driver shall invoke callbacks without holding the command or context lock.

`API-CB-003` — A callback shall not recursively perform a device transaction. It may schedule a later operation through an application-owned queue.

`API-CB-004` — Callback overflow, suppression, exception-equivalent failure, or deadline overrun shall be reported as software evidence and shall not clear device evidence.

# 48. Thread Safety and Interrupt-Context Rules

## 48.1 Context Classification

| Context | Permitted operations |
|---|---|
| Hard interrupt top half | `dfc_interrupt_service_request` and BSP host-controller primitives only |
| Deferred service thread/task | Bounded interrupt/event service and callback queueing |
| Ordinary caller | All APIs allowed by lifecycle and lock policy |
| Callback | Nondestructive software-only queries and scheduling; no recursive device transaction |

## 48.2 Rules

`API-CTX-001` — All public functions shall be thread-safe for distinct device contexts.

`API-CTX-002` — Concurrent calls on one context shall be serialized or rejected according to the documented operation class; no call shall interleave a protected, staged, snapshot, selector, or reconciliation workflow.

`API-CTX-003` — Destruction requires proof that no call, callback, deferred service, or BSP top half can still reference the context.

`API-CTX-004` — Cancellation is a software request. Once a state-changing command may have been accepted, cancellation shall transition to reconciliation rather than claim rollback.

# 49. Diagnostics and Engineering API

## 49.1 Production Diagnostics

| Function | Contract |
|---|---|
| `dfc_diagnostics_read_host` | Read host status, counters, sticky transport evidence, and last terminal reconciliation record |
| `dfc_diagnostics_read_reset_clock` | Read current and sticky reset/clock evidence distinctly |
| `dfc_diagnostics_read_loss` | Read module overflow, underflow, rejection, and drop evidence/counters |
| `dfc_diagnostics_clear_evidence` | Execute only an explicitly typed W1C or whole-counter clear selected by the caller |
| `dfc_reset_request` | Execute one protected Register-Map-defined system, module, or safety-domain reset request; report terminal reset status when available; invalidate cached state; and enter recovery before later ordinary work |

## 49.2 Engineering Raw Access

An optional engineering build may expose `dfc_engineering_read_register` and `dfc_engineering_write_register`. These functions shall use generated identifiers, command serialization, ordinary protocol validation, lifecycle enforcement, and complete result reporting.

`API-DIAG-001` — Engineering raw access shall be compile-time disabled in production profiles.

`API-DIAG-002` — Engineering access shall not expose unimplemented addresses, test/scan backdoors, wrapper-private paths, shared-buffer physical addresses, or RTL hierarchy.

`API-DIAG-003` — Diagnostic reads and clears shall preserve the Register Map's independence among current state, sticky evidence, counters, interrupts, faults, events, queues, and reconciliation records.

`API-DIAG-004` — Reset scope shall use the generated legal one-hot request type. Multiple scopes, unsupported module scopes, and reserved bits shall be rejected without device access.

`API-DIAG-005` — An ambiguous reset request shall not be repeated. Recovery shall first rediscover identity and reset state, then reconcile terminal evidence when available, and finally require reapplication of nondefault volatile configuration according to caller policy.

# 50. Initialization Sequence

The following sequence is normative for the library workflow but does not redefine device startup:

1. Construct the context with validated storage, BSP operations, options, and software capacities.
2. Establish the BSP-defined post-reset SPI quiet condition and host-controller readiness.
3. Open the context and read device identity, register-map revision, capability, host readiness, system status, and initial diagnostics.
4. Select and validate the exact generated-binding compatibility profile.
5. Read the active volatile configuration and retained evidence needed by caller policy.
6. Compare desired external configuration to active configuration.
7. Apply a reviewed configuration plan with protected and staged groups explicit.
8. Read back every changed active object and verify required module readiness.
9. Configure device interrupt enables, then register and unmask the external host interrupt.
10. Enable operational behavior only through a separate caller-authorized action after all required preconditions hold.

`API-INIT-001` — Failure at any step shall leave the context in OPEN with operation disabled when safe to continue, RECOVERY_REQUIRED when state is uncertain, or FAILED when invariants cannot be preserved.

`API-INIT-002` — Initialization shall preserve and report preexisting evidence before any caller-authorized clear.

# 51. Runtime Service Sequence

One runtime service iteration shall prioritize externally imposed deadlines and safety-relevant evidence without redefining firmware scheduling policy:

1. Admit at most one serialized device workflow.
2. Service watchdog only when application health and the legal service-window policy permit.
3. Service pending host interrupt work and reread pending state before unmask.
4. Retrieve bounded event and communication data into software-owned queues.
5. Persist or hand off raw evidence before destructive pop or clear when policy requires.
6. Execute approved configuration or command work.
7. Poll required health, fault, loss, and diagnostic state not covered by interrupt policy.
8. Dispatch bounded callbacks outside driver locks.

`API-RUN-001` — Software queue backpressure shall not block the command coordinator indefinitely. The driver shall report software-side loss or refusal separately from device-side loss.

`API-RUN-002` — Reconnect, reset evidence, identity change, or ambiguous state-changing completion shall preempt ordinary work and enter recovery.

# 52. FPGA Validation Access Sequence

FPGA validation shall use the public driver and VisionFive 2 BSP through the common logical wrapper. A validation harness may correlate driver records with approved FPGA observability, but pass/fail behavior shall use the controlling specifications and Verification Plan as the oracle.

`API-FPGA-001` — The validation sequence shall cover minimum and maximum command lengths, every definitive status class, zero/two wait-fill bounds, partial multiword completion, pre-acceptance abort, response truncation, timeout, CRC failure, protected access, staged commit, snapshot/pop, reset, and reconciliation.

`API-FPGA-002` — Removing all validation-only instrumentation shall not change portable driver behavior.

# 53. Production ASIC Access Sequence

Production ASIC access shall use the same portable driver and generated logical bindings with a production external-host BSP. Bring-up shall begin with identity and nondestructive status reads, then exercise bounded typed functions before any operational enable.

`API-ASIC-001` — There is no ASIC-local software, RISC-V BSP, direct memory map, or OpenFrame-supplied host interface.

`API-ASIC-002` — Post-silicon tests shall not use an undocumented path to compensate for a nonconforming SPI or register contract.

`API-ASIC-003` — Device build identity and production-host BSP identity shall be recorded independently in bring-up evidence.

# 54. Unit Test Requirements

## 54.1 Required Unit Coverage

Unit tests shall cover:

- every public argument, lifecycle, context, deadline, and storage validation branch;
- command encoding and response decoding for every supported word count and operation class;
- CRC known-answer, single-bit corruption, boundary, and independent-reference tests;
- every software status mapping and preserved raw device status;
- partial completion at every possible word position;
- malformed marker, fill, reserved byte, length, count, status, and CRC;
- protected workflow invalidation and noninterleaving;
- selector, snapshot/pop, stage/commit, counter-clear, W1C, service, recovery, and reset helpers;
- ambiguous-outcome reconciliation classifications;
- callback capacity, unregister race, reentrancy rejection, and dispatch bounds;
- lock order, concurrent caller, cancellation, close, recovery, and destruction races; and
- generated-binding manifest and public-header conformance.

`API-UT-001` — Tests shall use a deterministic BSP double capable of failure before submission, during transfer, after possible acceptance, during response, and after complete device execution.

`API-UT-002` — Every side-effecting API shall have tests proving that automatic retry is absent when completion may be ambiguous.

`API-UT-003` — Statement, branch, and condition coverage shall be reported; safety- or state-critical defensive branches shall be justified when unreachable.

# 55. FPGA Validation Requirements

FPGA validation shall satisfy the host-system responsibilities allocated by `PBIO-VER-008` using the Verification Plan-defined methods and evidence. At minimum, validation shall demonstrate:

- correct VisionFive 2 SPI-master and interrupt-receiver behavior;
- compatibility discovery and generated binding selection;
- deterministic configuration application and active readback;
- interrupt, event, queue, communication, diagnostic, and counter service;
- response-loss reconciliation and safe retry refusal;
- reset recovery and reapplication of nondefault volatile configuration;
- preservation of raw evidence through external handoff and persistence; and
- absence of FPGA-private dependencies.

`API-FV-001` — Software evidence shall identify applicable VP case IDs and controlling requirement/register identifiers without redefining their expected results.

# 56. ASIC Bring-Up Validation Requirements

Post-silicon validation shall repeat the common host-contract suite through the production BSP and compare logical results with the verified FPGA baseline where the controlling contract requires equivalence.

`API-AV-001` — Bring-up shall verify SPI electrical/controller integration separately from logical response correctness so ownership failures remain distinguishable.

`API-AV-002` — Identity, reset-safe state, readiness, compatibility, active defaults, protected operations, interrupts, event retrieval, representative module workflows, diagnostics, reset, truncation recovery, and reconciliation shall pass before operational use.

`API-AV-003` — A physical-platform variance shall be corrected in its owning integration or BSP artifact and shall not be hidden by portable-driver conditionals.

# 57. Deliverables

The approved implementation baseline shall include:

- public C17 headers and API reference generated from them;
- portable driver source and internal design description;
- each supported BSP source and platform integration guide;
- generated Register Map bindings, source identity, generator, and manifest;
- unit-test BSP double, protocol oracle, fixtures, and test source;
- unit, static-analysis, coverage, integration, FPGA, and ASIC evidence as applicable;
- build, dependency, compiler, linker, option, and license manifests;
- compatibility matrix and release notes;
- trace records from `API-*` requirements to implementation and tests; and
- known-deviation records approved through project change control.

`API-DEL-001` — Generated bindings and release manifests are required deliverables, not disposable build intermediates.

`API-DEL-002` — No deliverable shall contain credentials, private keys, unrestricted test authorization, or undocumented production access.

# 58. Exit Criteria

Revision B implementation is complete only when:

- every `API-*` requirement is implemented or formally dispositioned;
- all public headers compile as C17 and under a supported C++ compatibility compile;
- all generated bindings match the approved Register Map source and manifest;
- unit, static-analysis, sanitizer where applicable, coverage, integration, and hardware tests pass;
- every state-changing API has ambiguity, partial-completion, deadline, and retry tests;
- each BSP satisfies continuous chip-select, timing, actual-length, cancellation, interrupt, lock, and ordering requirements;
- FPGA validation satisfies applicable host-system VP cases;
- production BSP and ASIC bring-up evidence satisfy the applicable release phase;
- no direct MMIO, ASIC-local software, hidden access path, copied register authority, or unapproved FPGA dependency remains;
- configuration, identity, diagnostic, and persistence responsibilities remain external as allocated;
- all controlling-specification flags are resolved; and
- configuration control records the approved source, generated artifacts, tools, options, tests, and evidence.

# 59. Baseline Statement

## 59.1 Baseline Declaration

RCA-DFC-SW-003 Revision B is the implementation and public-interface baseline for the Dragon Core Revision A external-host HAL, driver library, and BSP API. It supersedes Revision A for all new software development, verification, release, and maintenance use.

## 59.2 Governing Relationship

This specification remains subordinate to the eight controlling specifications identified by `RCA-DFC-CHTR-002`, Section 3.1, and implements `RCA-DFC-SW-001` Revision C and `RCA-DFC-SW-002` Revision B. It creates no alternate product, boundary, externally observable behavior, internal architecture, register, verification, RTM, or RTL definition.

## 59.3 Fixed Baseline Conclusions

- Dragon Core is processor-free and contains no firmware, BSP, processor, executable memory, or software runtime.
- All HAL, driver, BSP, application, configuration, persistence, and recovery software executes on an external host.
- FPGA and ASIC use one SRS-defined SPI transport and one Register-Map-defined logical programming model.
- The portable driver uses generated bindings, one serialized command coordinator, exact result reporting, and typed side-effecting workflows.
- Multiword operations remain ordered and non-atomic except where the Register Map defines explicit atomic commit.
- State-changing operations with uncertain completion are reconciled and read back; they are never blindly retried.
- Current, sticky, counter, pending, staged, active, requested, commanded, effective, terminal, cached, derived, and stale states remain distinct.
- Host-controller acknowledgement, Dragon Core interrupt acknowledgement, device evidence clear, event pop, queue push, watchdog service, reset, and recovery remain distinct operations.
- Production and engineering capabilities remain isolated.

## 59.4 Controlling-Specification Disposition

No change to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, or `RCA-DFC-RTL-STD-002` is required to establish this Revision B API baseline.

## 59.5 Change Control

Any future change to API semantics, lifecycle, context storage, concurrency, BSP capabilities, result classification, callback behavior, generated-binding use, compatibility, or software verification shall revise this specification and complete downstream impact analysis. A change requiring new device behavior, register meaning, interface behavior, verification definition, trace relationship, or RTL rule shall first revise the applicable controlling specification.

## 59.6 Approval Statement

Upon approval, this document is ready for direct placement beneath the eight controlling Dragon Flight specifications as `RCA-DFC-SW-003_Dragon_Core_HAL_Driver_and_BSP_API_Specification_RevB.md`.
