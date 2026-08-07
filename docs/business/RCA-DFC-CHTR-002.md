# Dragon Core Technical Charter

- **Document ID:** RCA-DFC-CHTR-002
- **Product:** Dragon Core Revision A
- **Program:** Dragon Flight Core ASIC Development Program
- **Organization:** Royal Cubit Aerospace
- **Purpose:** Define the product mission, included and excluded scope, selected technical platforms, external-host model, and fixed top-level technical constraints for Dragon Core Revision A.

## 1. Purpose

This Charter is the highest-level technical specification for Dragon Core Revision A. It defines the product mission, product scope, product exclusions, selected implementation platforms, external-host model, and fixed technical constraints that every subordinate specification and derived artifact shall preserve.

This Charter does not define detailed externally observable behavior, quantitative performance, internal protocols, module interfaces, register fields, implementation rules, verification procedures, or trace relationships. Those subjects are owned by the documents identified in Section 3.

## 2. Normative Language

The terms **shall** and **shall not** identify mandatory technical constraints. **Should** identifies a preferred technical approach. **May** identifies a permitted option.

Revision A is the technical product designation used throughout the specification set.

## 3. Technical Specification Hierarchy and Ownership

### 3.1 Canonical Technical Specification Set

The Dragon Core Revision A top-level technical specification set consists of the following eight documents in canonical filename order:

The ordinal order identifies the canonical file sequence. Subject ownership, not ordinal precedence, determines which document controls a technical fact.

| Order | Document | Sole normative subject ownership |
|---:|---|---|
| 1 | `RCA-DFC-CHTR-002.md` | Product mission; included and excluded scope; selected platforms; external-host model; fixed top-level technical constraints |
| 2 | `RCA-DFC-PBIO-002.md` | Device, platform, board, aircraft, software, interface, and verification responsibility boundaries |
| 3 | `RCA-DFC-SRS-002.md` | Externally observable functional behavior; capacities; performance; timing; safety; reliability; environmental constraints; external logical interfaces |
| 4 | `RCA-DFC-ARCH-002.md` | Internal decomposition; module allocation; algorithms; states; priorities; internal interfaces and protocols; clocks and resets; CDC/RDC; shared types; numeric allocations; logical wrapper architecture |
| 5 | `RCA-DFC-REG-002.md` | Host-visible register offsets; fields; access classes; reset values; encodings; validation; read behavior; write behavior; side effects |
| 6 | `RCA-DFC-VP-002.md` | Verification methods; environments; cases; coverage; required technical outcomes; verification evidence definitions |
| 7 | `RCA-DFC-RTM-002.md` | Relationships among existing requirement, architecture, register, module, and verification identifiers |
| 8 | `RCA-DFC-RTL-STD-002.md` | SystemVerilog implementation rules, coding conventions, structural rules, and reusable RTL conformance requirements |

### 3.2 Single-Owner Rules

| ID | Technical constraint |
|---|---|
| CHTR-DOC-001 | Each technical fact shall have exactly one normative owner. |
| CHTR-DOC-002 | A document shall define only subjects assigned to it by Section 3.1. |
| CHTR-DOC-003 | A document that consumes another document's technical fact shall cite an owning identifier and shall not repeat, strengthen, weaken, specialize, or redefine the owned technical fact. |
| CHTR-DOC-004 | A repeated table or operational view shall be identified as a generated, nonnormative view and shall be produced from the normative owner. |
| CHTR-DOC-005 | A conflict, ambiguity, omission, or incomplete definition shall be corrected in the owning specification; document order shall not be used to preserve competing definitions. |
| CHTR-DOC-006 | No implementation, RTL module specification, software artifact, testbench, or integration artifact shall invent behavior that is absent from the applicable owning specification. |
| CHTR-DOC-007 | Derived artifacts shall preserve the identifiers, terminology, signal names, constants, encodings, units, and interfaces defined by their normative owners. |

### 3.3 Derived Technical Artifacts

RTL module specifications, RTL source code, testbenches, assertions, generated packages, software headers, host drivers, and verification evidence are derived artifacts. They shall implement or verify the eight-document technical specification set and shall not become alternate sources of product definition.

The future Dragon Core ASIC Integration Specification shall own only technology-specific physical implementation inputs, including the selected OpenFrame release, process-design-kit version, physical-design flow, package and physical pad mapping, voltage and power-domain assignments, technology macros, scan implementation, and physical timing constraints. It shall preserve the complete logical wrapper contract owned by the Architecture Specification and shall not alter the product behavior owned by the SRS or Register Map Specification.

## 4. Product Identity and Mission

Dragon Core Revision A is a reusable avionics supervisory ASIC for deterministic monitoring, timing, event recording, digital databus handling, health supervision, safety supervision, bounded hardware adaptation, and host-observable evidence collection.

Dragon Core is infrastructure and supervisory hardware. It is not an aircraft application computer and shall not perform aircraft-specific flight management, navigation, guidance, mission execution, or vehicle control.

### 4.1 Fixed Product Constraints

| ID | Technical constraint |
|---|---|
| CHTR-TECH-001 | Dragon Core Revision A shall be implemented as a processor-free digital hardware ASIC. |
| CHTR-TECH-002 | All executable software and all general-purpose host computing shall remain outside the fabricated Dragon Core device. |
| CHTR-TECH-003 | Dragon Core shall perform required startup, monitoring, communication, evidence collection, fault handling, interlock, lost-link, and safety-supervision functions through deterministic digital hardware. |
| CHTR-TECH-004 | The fabricated Dragon Core device shall not contain or reserve an instruction-executing processor, software runtime, processor boot or runtime memory, unrestricted internal system bus, field-programmable fabric, or unspecified expansion interface. |
| CHTR-TECH-005 | Production user logic shall be finite, bounded, and fixed by fabrication masks. It shall not be structurally reprogrammable after fabrication. |

## 5. Selected Technical Platforms

### 5.1 Production ASIC Platform

ChipIgnite OpenFrame is the selected Dragon Core Revision A production ASIC integration and fabrication platform.

OpenFrame is a platform boundary and does not define the Dragon Core product architecture. Dragon Core shall not depend on OpenFrame to supply the product host transport, host-visible register endpoint, internal register interconnect, interrupt handling, event handling, application management, general-purpose processing, or software execution environment.

The Architecture Specification shall define a complete technology-independent logical wrapper for Dragon Core. Technology-specific physical selections shall be confined to the future ASIC Integration Specification identified in Section 3.3.

### 5.2 FPGA Validation Platform

Lattice ECP5 is the selected primary FPGA validation technology, and VisionFive 2 is the selected primary external validation host.

The FPGA realization shall preserve the technology-independent behavior and logical interfaces of the production design. FPGA clocks, resets, memories, pads, and other vendor resources shall remain isolated behind controlled technology wrappers and shall not become required dependencies of the production ASIC.

### 5.3 Platform Constraints

| ID | Technical constraint |
|---|---|
| CHTR-TECH-006 | The same technology-independent Dragon Core RTL shall be used for FPGA validation and production ASIC implementation. |
| CHTR-TECH-007 | FPGA-specific and ASIC-specific resources shall remain behind explicit technology wrappers. |
| CHTR-TECH-008 | A platform wrapper or physical-integration artifact shall not alter the logical interfaces, register contract, or externally required functional behavior. |

## 6. External-Host Model

Dragon Core shall operate as a mapped hardware peripheral controlled and observed by a computing system outside the fabricated device. Production host access shall use an SPI transport. Detailed external protocol behavior is owned by the SRS; its internal realization is owned by the Architecture Specification; and host-visible register meaning is owned by the Register Map Specification.

The external host shall own executable software, application policy, configuration databases, nonvolatile configuration storage, long-term operational-data storage, diagnostics, maintenance tools, and reapplication of nondefault volatile configuration after reset or power loss.

Dragon Core shall reach host-access-ready operation and perform configured autonomous hardware supervision without executing software inside the device. Continuous host participation shall not be required except where an SRS-defined host service, watchdog, or lost-link behavior explicitly makes host activity observable.

### 6.1 Host-Interface Constraints

| ID | Technical constraint |
|---|---|
| CHTR-TECH-009 | The logical register programming model shall remain independent of external-host processor architecture, operating system, and software framework. |
| CHTR-TECH-010 | External transport, internal register transport, FPGA wrappers, ASIC wrappers, and physical integration shall preserve one host-visible register contract. |
| CHTR-TECH-011 | Dragon Core shall reach host-access-ready operation through deterministic hardware startup without executing on-device software. |
| CHTR-TECH-012 | Configured hardware supervision shall continue without continuous host participation, subject only to behavior explicitly defined by the SRS. |

## 7. Included Product Scope

The following capability groups are included within Dragon Core Revision A. Exact channel counts, capacities, encodings, timing, interfaces, and acceptance criteria are owned by the SRS, Architecture Specification, and Register Map Specification as allocated in Section 3.1.

| ID | Included capability group | Included high-level capability |
|---|---|---|
| CHTR-SCOPE-001 | Infrastructure | Host-accessible configuration and control; deterministic operating-state control; interrupt collection and host notification; timestamp generation; event collection and retrieval; general-purpose digital I/O; production-test and integration diagnostics |
| CHTR-SCOPE-002 | Digital databus | ARINC 429 receive logic; ARINC 429 transmit logic; Classical CAN controller logic; UART controller logic; bounded databus routing |
| CHTR-SCOPE-003 | Monitoring and health | Rotor-speed monitoring; engine-speed monitoring; pulse and frequency measurement; conditioned sensor supervision; discrete and system-health monitoring |
| CHTR-SCOPE-004 | Safety supervision | Watchdog supervision; fault collection and response; interlock evaluation; lost-link supervision; logical safety-output control |
| CHTR-SCOPE-005 | Bounded hardware adaptation | Mask-defined user logic and finite user-configurable routing among explicitly defined endpoints |
| CHTR-SCOPE-006 | Top-level logical integration | Host-access integration; clock and reset integration; logical pad control and safe defaults; CDC/RDC; external-interface digital adaptation; shared hardware resources; production-test and diagnostic integration |
| CHTR-SCOPE-007 | Platform realizations | OpenFrame-compatible production ASIC realization and ECP5 FPGA validation realization of the same technology-independent Dragon Core design |

## 8. Product Exclusions

The following functions are outside the Dragon Core Revision A fabricated-device boundary.

| ID | Excluded function class | Excluded functions |
|---|---|---|
| CHTR-EXCL-001 | Aircraft application functions | Flight control; autopilot; navigation; guidance; mission management; vehicle-control decision making; sensor fusion; state estimation; computer vision; artificial intelligence; aircraft user interfaces |
| CHTR-EXCL-002 | On-device computing and software | General-purpose processors; management processors; embedded computer subsystems; operating systems; software runtimes; firmware applications; processor boot or runtime memory; caches; stacks; exception systems; processor debug facilities; on-device HAL, BSP, middleware, or applications |
| CHTR-EXCL-003 | Analog and electrical interface functions | Analog sensor conditioning; ADCs; DACs; ARINC electrical line receivers and drivers; CAN transceivers and termination; UART voltage conversion and isolation; board-level signal protection; level translation; external signal isolation |
| CHTR-EXCL-004 | Aircraft wiring and energy control | Aircraft wiring and connectors; power conversion; external power supervision; relay, contactor, valve, motor, or actuator power drivers; final control of aircraft energy |
| CHTR-EXCL-005 | External data and application policy | Nonvolatile configuration storage; long-term operational-data storage; maintenance databases; aircraft-specific application policy; installation-specific calibration and unit conversion |
| CHTR-EXCL-006 | Aircraft-level assurance | Aircraft safety assessment; installation approval; operational authorization; aircraft certification activities |

## 9. Fixed Boundary Principles

The PBIO Specification shall assign detailed ownership at the device, platform, board, aircraft, software, interface, and verification boundaries while preserving the following Charter-level constraints.

| ID | Technical constraint |
|---|---|
| CHTR-TECH-013 | Dragon Core shall own digital protocol behavior inside the defined device boundary; external circuitry shall own electrical adaptation unless the PBIO explicitly assigns a different owner. |
| CHTR-TECH-014 | Dragon Core safety outputs shall be logical low-voltage signals and shall require external circuitry to control aircraft energy. |
| CHTR-TECH-015 | External software shall own application policy, nonvolatile persistence, long-term data storage, and installation-specific interpretation. |
| CHTR-TECH-016 | Every external and internal interface shall have an identified producer, consumer, clock and reset context, logical owner, physical owner, protocol owner, error owner, and verification owner. |

## 10. Technical Design Principles

| ID | Principle |
|---|---|
| CHTR-PRN-001 | **Deterministic startup:** Required hardware state shall initialize to defined safe values without on-device software. |
| CHTR-PRN-002 | **Single logical register contract:** Every host-access path shall implement one transport-independent host-visible register model. |
| CHTR-PRN-003 | **Explicit ownership:** Functional state, protocol behavior, physical adaptation, error handling, shared resources, and verification responsibility shall be unambiguous. |
| CHTR-PRN-004 | **Safe behavior:** Reset, startup, disabled, observational, test, fault, invalid, reserved, and unused conditions shall have defined safe behavior. |
| CHTR-PRN-005 | **Finite resources:** Buffers, routes, sources, destinations, queues, channels, user functions, and test mechanisms shall be bounded and enumerated by their owning specifications. |
| CHTR-PRN-006 | **Observable loss and rejection:** Overflow, rejection, timeout, protocol error, access failure, and dropped evidence shall produce the persistent indication required by the owning specification. |
| CHTR-PRN-007 | **Deterministic simultaneity:** Every simultaneous set, clear, command, input, error, and reset condition capable of changing the result shall have an explicit priority in the owning specification. |
| CHTR-PRN-008 | **Technology isolation:** Functional RTL shall remain independent of FPGA and ASIC technology primitives. |
| CHTR-PRN-009 | **Requirements-based derivation:** Externally observable behavior shall derive from the SRS; responsibility allocation shall derive from the PBIO Specification; internal design shall derive from the Architecture Specification; host-register realization shall derive from the Register Map Specification; RTL implementation shall conform to the RTL Coding Standard; verification shall derive from the Verification Plan; and trace relationships shall derive from the RTM. |
| CHTR-PRN-010 | **Complete specification:** The technical specification set shall define all behavior needed to derive RTL module specifications, RTL, testbenches, assertions, generated packages, host-interface artifacts, and the logical ASIC integration without local invention. |
