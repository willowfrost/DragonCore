# Dragon Core Product Boundary and Interface Ownership Specification

- **Document ID:** RCA-DFC-PBIO-002
- **Product:** Dragon Core Revision A
- **Program:** Dragon Flight Core ASIC Development Program
- **Organization:** Royal Cubit Aerospace
- **Purpose:** Define the device, platform, board, aircraft, software, interface, shared-resource, physical-integration, and verification responsibility boundaries for Dragon Core Revision A.

## 1. Purpose

This specification is the sole normative owner of product-boundary and interface-responsibility allocation for Dragon Core Revision A. It identifies what is owned inside the Dragon Core logical design, what is supplied by the selected production and validation platforms, what remains outside the fabricated device, and which owner is responsible for each aspect of an interface.

This specification does not define product mission or included capability scope; externally observable behavior or timing; internal algorithms, state machines, signal encodings, module ports, clocks, resets, CDC/RDC mechanisms, or numeric allocations; register fields; SystemVerilog implementation rules; verification methods; or trace relationships. Those subjects remain with the owners assigned by `RCA-DFC-CHTR-002`, Section 3.

## 2. Normative Language

The terms **shall** and **shall not** identify mandatory responsibility allocations. **Should** identifies a preferred allocation. **May** identifies a permitted allocation.

An **owner** is the party, hardware element, integration artifact, software element, or verification scope responsible for the correctness of an assigned interface aspect. Assignment of responsibility does not transfer ownership of a technical definition from the document designated by `RCA-DFC-CHTR-002`.

## 3. Relationship to the Technical Specification Set

This specification shall preserve the Charter constraints identified below and shall apply the single-owner rules `CHTR-DOC-001` through `CHTR-DOC-007`.

| ID | Controlling Charter subject | Controlling identifiers |
|---|---|---|
| PBIO-REF-001 | Processor-free fabricated device and external software boundary | `CHTR-TECH-001` through `CHTR-TECH-005`; `CHTR-EXCL-002` |
| PBIO-REF-002 | Production and FPGA platform selections and technology isolation | `CHTR-TECH-006` through `CHTR-TECH-008` |
| PBIO-REF-003 | External-host model and single logical register contract | `CHTR-TECH-009` through `CHTR-TECH-012` |
| PBIO-REF-004 | Included capability groups | `CHTR-SCOPE-001` through `CHTR-SCOPE-007` |
| PBIO-REF-005 | Product exclusions | `CHTR-EXCL-001` through `CHTR-EXCL-006` |
| PBIO-REF-006 | Fixed product-boundary constraints | `CHTR-TECH-013` through `CHTR-TECH-016` |
| PBIO-REF-007 | Technology-specific ASIC integration ownership | `RCA-DFC-CHTR-002`, Section 3.3 |

The canonical document set and each document's sole normative subject are defined only by `RCA-DFC-CHTR-002`, Section 3. This specification shall cite those owners when assigning a responsibility that consumes their technical definitions and shall not reproduce the Charter's document-ownership table.

## 4. Boundary Terms and Responsible Parties

| Term | Boundary meaning |
|---|---|
| **Dragon Core logical design** | The complete technology-independent digital design, including RTL-024, RTL-001 through RTL-023, and technology-independent shared resources and adapters allocated by the Architecture Specification. |
| **Dragon Core logical wrapper boundary** | The Architecture-defined external logical interface of RTL-024 through which the technology-independent design connects to a platform wrapper. |
| **ASIC technology wrapper** | Technology-specific logic and cells that connect the Dragon Core logical wrapper boundary to the selected OpenFrame platform resources. |
| **FPGA technology wrapper** | Technology-specific logic and resources that connect the same Dragon Core logical wrapper boundary to the selected ECP5 validation platform. |
| **OpenFrame platform boundary** | Platform-supplied padframe, permitted power and reset resources, project-identification resource, submission wrapper, and physical-design boundary selected for the production device. |
| **Fabricated-device boundary** | The complete OpenFrame-fabricated device, consisting of platform-supplied resources, the ASIC technology wrapper, and the Dragon Core logical design. |
| **External board boundary** | Circuitry outside the fabricated device that supplies electrical adaptation, conditioning, protection, transceivers, termination, isolation, power drive, connectors, and board wiring. |
| **Aircraft boundary** | Aircraft wiring, sensors, actuators, energy-control equipment, operational systems, installation policy, and aircraft-level assurance activities outside the Dragon Core product. |
| **External host hardware owner** | The owner of the processor, SPI controller, interrupt input, host clocks and reset coordination, memory, and physical connection used to control and observe Dragon Core. |
| **External host software owner** | The owner of drivers, hardware-abstraction software, configuration and diagnostic tools, applications, data interpretation, persistence, and maintenance software executed outside the fabricated device. |
| **ASIC integration owner** | The owner of the future ASIC Integration Specification and the technology-specific artifacts identified by `PBIO-REF-007`. |
| **FPGA integration owner** | The owner of the ECP5 wrapper, constraints, board mapping, validation-only observability, and technology-specific build artifacts. |
| **Board or aircraft integrator** | The owner responsible for external electrical interfaces, installation-specific circuitry, wiring, equipment compatibility, and system use. |
| **External test owner** | The owner of production-test or laboratory equipment, fixtures, physical stimulus, capture, and equipment-side interpretation. |

## 5. Boundary-Layer Allocation

The following table is the sole boundary-layer allocation for Dragon Core Revision A. Downstream specifications shall refer to it and shall not recreate a competing boundary model.

| Boundary layer | Included responsibility | Primary owner | Excluded responsibility |
|---|---|---|---|
| OpenFrame platform | Platform-supplied fabrication boundary and resources made available to the user project | OpenFrame platform provider | Dragon Core host transport, register endpoint, internal interconnect, functional control, software execution, and product-specific safe-state policy |
| ASIC technology wrapper | Technology-cell instantiation and physical connection between OpenFrame resources and the Dragon Core logical wrapper boundary | ASIC integration owner | Product behavior, logical register meaning, and internal functional algorithms |
| Dragon Core logical design | Digital implementation of the Charter capability groups and complete logical top-level integration | Royal Cubit Aerospace | Platform physical implementation, board circuitry, aircraft wiring, and executable software |
| FPGA technology wrapper | ECP5-specific realization of the Dragon Core logical wrapper boundary | FPGA integration owner | Production behavior that is absent from the ASIC realization or any alternate product architecture |
| External host hardware | SPI-master and interrupt-receiver hardware and its connection to Dragon Core | External host hardware owner | Dragon Core target behavior, internal register access, or on-device safety supervision |
| External host software | Configuration policy, service, diagnostics, interpretation, persistence, and application behavior | External host software owner | Enforcement of any safety responsibility assigned to Dragon Core hardware |
| External board and aircraft | Electrical adaptation, physical interfaces, installation, energy control, and aircraft functions | Board or aircraft integrator | Dragon Core logical protocol and host-register behavior |
| External test environment | Physical test access, stimulus, observation, and fixture operation | External test owner | Undocumented access or alteration of Dragon Core functional behavior |

## 6. General Responsibility Rules

| ID | Responsibility allocation |
|---|---|
| PBIO-OWN-001 | An interface producer shall own the correctness, stability, validity indication, and protocol obligations of information through its output boundary. |
| PBIO-OWN-002 | An interface consumer shall own compliant acceptance, interpretation, use, and backpressure or response behavior after its input boundary. |
| PBIO-OWN-003 | The logical owner shall own the purpose and functional use of the interface, subject to the behavior defined by the SRS and Architecture Specification. |
| PBIO-OWN-004 | The protocol owner shall own framing, sequencing, handshake, arbitration, timeout detection, protocol-error detection, and protocol recovery. |
| PBIO-OWN-005 | The physical owner shall own voltage, current, impedance, termination, drive, protection, isolation, electrical timing, and signal integrity on its side of the boundary. |
| PBIO-OWN-006 | The error owner shall detect, retain, classify, report, and recover from errors assigned to its side of the boundary; an error shall not become unowned because its cause originates across the boundary. |
| PBIO-OWN-007 | The connection owner shall own width, direction, type, pad or endpoint mapping, tie-offs, unused connections, clock/reset association, and connectivity between already-defined interfaces. |
| PBIO-OWN-008 | The verification owner shall verify the assigned responsibility using the methods and evidence defined only by the Verification Plan. |
| PBIO-OWN-009 | A platform wrapper, board circuit, host driver, test fixture, or receiving module shall not compensate for undefined or nonconforming behavior owned by the producer. |
| PBIO-OWN-010 | An interface crossing two ownership regions shall retain separate logical, protocol, physical, error, connection, and verification owners where those responsibilities differ. |
| PBIO-OWN-011 | An implementation artifact shall not create an undocumented alternate owner, bypass path, hidden interface, or shared-resource access path. |
| PBIO-OWN-012 | A responsibility not allocated by this specification shall be assigned here before a downstream specification or derived artifact depends upon it. |

## 7. Production ASIC and OpenFrame Ownership

| ID | Responsibility allocation |
|---|---|
| PBIO-ASIC-001 | The OpenFrame platform provider shall own correctness of the platform resources and platform submission boundary supplied to the Dragon Core project. |
| PBIO-ASIC-002 | Royal Cubit Aerospace shall own all Dragon Core product-specific digital logic and logical integration; no Dragon Core product function shall be presumed to exist in OpenFrame unless it is explicitly assigned as a platform resource by the ASIC Integration Specification. |
| PBIO-ASIC-003 | The Architecture Specification shall own the complete technology-independent Dragon Core logical wrapper contract. |
| PBIO-ASIC-004 | The ASIC integration owner shall own the technology-specific connection from the Dragon Core logical wrapper boundary to the selected OpenFrame resources. |
| PBIO-ASIC-005 | The ASIC integration owner shall own the selected OpenFrame release, process-design-kit version, physical-design flow, technology cells and macros, physical pad and package mapping, voltage and power-domain mapping, scan realization, physical constraints, and physical timing closure. |
| PBIO-ASIC-006 | The ASIC integration owner shall preserve the logical wrapper, register, externally observable, safe-state, and technology-isolation contracts owned by the eight-document technical specification set. |
| PBIO-ASIC-007 | The ASIC integration owner shall own deterministic tie-off and physical disposition of every unused platform or wrapper resource. |
| PBIO-ASIC-008 | The board or aircraft integrator shall own all circuitry and wiring beyond the fabricated-device pads. |
| PBIO-ASIC-009 | A platform identification resource shall remain platform or integration metadata and shall not become processor boot memory, firmware storage, application storage, or a second host-control path. |

The future ASIC Integration Specification identified by `PBIO-REF-007` completes the physical realization without reopening any logical product decision. Its technology-specific selections are implementation inputs, not missing Dragon Core logical behavior.

## 8. FPGA Validation Ownership

| ID | Responsibility allocation |
|---|---|
| PBIO-FPGA-001 | The FPGA integration owner shall implement the same Architecture-defined Dragon Core logical wrapper contract used by the production ASIC realization. |
| PBIO-FPGA-002 | The FPGA integration owner shall own ECP5 I/O resources, clock and reset resources, memory wrappers, pin and board mapping, timing constraints, and validation-only observability. |
| PBIO-FPGA-003 | Royal Cubit Aerospace shall own the common technology-independent RTL used by both platform realizations. |
| PBIO-FPGA-004 | The FPGA board owner shall own board transceivers, voltage conversion, conditioning, protection, connectors, wiring, fixtures, and board-level signal integrity. |
| PBIO-FPGA-005 | The external validation host owner shall own the VisionFive 2 SPI-master, interrupt-receiver, host-software, and host-side evidence responsibilities assigned in Sections 9 and 14. |
| PBIO-FPGA-006 | FPGA-only resources and observability shall remain owned by the FPGA wrapper and shall not become functional dependencies, external interfaces, storage mechanisms, or alternate behavior of the production device. |
| PBIO-FPGA-007 | Differences in physical resource realization between FPGA and ASIC wrappers shall be owned by their respective integration owners and verified at the common logical wrapper boundary. |

## 9. External Host and Software Ownership

| ID | Responsibility allocation |
|---|---|
| PBIO-HOST-001 | Dragon Core shall own SPI-target behavior, conversion to the internal register-access interface, host-visible interrupt generation, and on-device evidence required by the SRS. |
| PBIO-HOST-002 | The external host hardware owner shall own SPI-master behavior, compliance with host-side electrical and timing obligations, reception of the host interrupt, and the physical connection to Dragon Core. |
| PBIO-HOST-003 | The external host software owner shall own driver behavior, interrupt service, legal configuration selection, service policy, diagnostics, data retrieval, interpretation, and recovery actions assigned to software. |
| PBIO-HOST-004 | The external host software owner shall own nonvolatile configuration data, software images, long-term event and maintenance records, and all application data persistence. |
| PBIO-HOST-005 | Dragon Core shall own enforcement of every register-access, protected-write, configuration-validation, and command-side-effect rule defined by the Architecture and Register Map Specifications. |
| PBIO-HOST-006 | External software shall use only the SRS-defined host protocol and Register Map-defined host-visible contract; it shall not depend on platform-private, test, scan, or undocumented internal paths. |
| PBIO-HOST-007 | Reset or power loss shall transfer no volatile-state retention responsibility to Dragon Core beyond the retention explicitly defined by the SRS and Register Map; the host software owner shall own reapplication of nondefault volatile configuration. |
| PBIO-HOST-008 | Host absence, delay, malformed traffic, or software failure shall not transfer a Dragon Core hardware safety responsibility to software or suppress hardware evidence required by the SRS. |
| PBIO-HOST-009 | Installation-specific engineering-unit conversion, calibration databases, application policy, and operational interpretation shall remain external unless the SRS explicitly defines a Dragon Core-visible digital representation. |

## 10. Internal Logical-Design Ownership

### 10.1 Top-Level Integration

| ID | Responsibility allocation |
|---|---|
| PBIO-INT-001 | RTL-024 shall own technology-independent top-level integration of RTL-001 through RTL-023 and shall be the sole Dragon Core logical wrapper boundary presented to the ASIC and FPGA technology wrappers. |
| PBIO-INT-002 | RTL-024 shall own logical connection, tie-off, clock/reset distribution, external digital adaptation, host-transport integration, production-test integration, and centralized shared-resource integration assigned to the top level by the Architecture Specification. |
| PBIO-INT-003 | RTL-001 through RTL-023 shall own only the functional state and behavior allocated to each module by the Architecture Specification. |
| PBIO-INT-004 | Child modules shall communicate only through Architecture-defined interfaces connected by RTL-024 or through an Architecture-defined shared service; direct implicit coupling is not permitted. |
| PBIO-INT-005 | ASIC and FPGA technology wrappers shall instantiate technology resources outside RTL-024 and shall preserve the RTL-024 logical interface. |

### 10.2 Register Access and Functional State

| ID | Responsibility allocation |
|---|---|
| PBIO-REG-001 | RTL-024 shall own the external-host transport endpoint and its conversion to the Architecture-defined internal register-access protocol. |
| PBIO-REG-002 | RTL-001 shall own the sole host-visible internal register endpoint, address decoding, access enforcement, status collection, command distribution, and completion response allocated by the Architecture Specification. |
| PBIO-REG-003 | A functional module shall own the functional state and actions represented by its assigned control and status interface; RTL-001 shall not become an alternate owner of that functional behavior. |
| PBIO-REG-004 | The Architecture Specification shall own internal register-transport, request, response, ordering, timeout, CDC, and integration behavior. |
| PBIO-REG-005 | The Register Map Specification shall own offsets, fields, access classes, reset values, legal encodings, validation, read/write behavior, and side effects. |
| PBIO-REG-006 | External transport, internal transport, platform wrappers, generated packages, and host software shall preserve one Register Map-defined logical contract. |

### 10.3 Clocks, Resets, Power, Pads, and CDC/RDC

| ID | Responsibility allocation |
|---|---|
| PBIO-CLK-001 | The external clock-source owner shall own source generation, source tolerance, board-level distribution, and signal integrity up to the receiving platform boundary. |
| PBIO-CLK-002 | The applicable technology-wrapper owner shall own technology-specific clock cells, clock constraints, and the connection from the platform clock resource to the Dragon Core logical clock boundary. |
| PBIO-CLK-003 | RTL-024 shall own technology-independent clock qualification, logical distribution, clock-domain connection, and clock-related integration evidence allocated by the Architecture Specification. |
| PBIO-RST-001 | The platform or board reset-source owner shall own assertion of the physical reset source supplied to the applicable technology wrapper. |
| PBIO-RST-002 | The applicable technology-wrapper owner shall own technology-specific reset cells, physical reset connection, and reset constraints. |
| PBIO-RST-003 | RTL-024 shall own technology-independent reset qualification, distribution, domain release coordination, and local reset connection; each functional module shall own reset effects on its allocated state and outputs. |
| PBIO-PWR-001 | The board or aircraft integrator shall own external power generation, conversion, sequencing, supervision, protection, decoupling, and delivery to the fabricated device or FPGA board. |
| PBIO-PWR-002 | The OpenFrame platform provider and ASIC integration owner shall own platform power resources and technology-specific power-domain connection, respectively; the FPGA platform and FPGA integration owners shall own the corresponding validation-platform responsibilities. |
| PBIO-PWR-003 | The Dragon Core logical design shall not own external power management; any reset, health, or fault indication derived from power conditions shall transfer only the digital monitoring responsibility explicitly assigned by the SRS and Architecture Specification. |
| PBIO-PAD-001 | The applicable platform and technology-wrapper owners shall own physical pad cells, voltage-domain association, physical output enable, package or board-pin mapping, and physical unused-pad disposition. |
| PBIO-PAD-002 | RTL-024 shall own Architecture-defined logical direction, data, output-enable intent, input-enable intent, mode selection, logical safe defaults, and logical unused-interface behavior at the Dragon Core wrapper boundary. |
| PBIO-PAD-003 | The board or aircraft integrator shall own external pulls, protection, termination, isolation, connectors, wiring, voltage compatibility, and loading. |
| PBIO-CDC-001 | The Architecture Specification shall identify every required clock-domain and reset-domain crossing and shall define its source, destination, mechanism, reset interaction, reconvergence restrictions, and constraint requirements. |
| PBIO-CDC-002 | The producing and consuming RTL owners shall implement their respective source-side and destination-side protocol obligations; RTL-024 shall own crossing structures allocated to top-level integration. |
| PBIO-CDC-003 | The applicable technology-wrapper owner shall preserve Architecture-defined CDC/RDC structures and shall own implementation constraints and physical checks applicable to the selected technology. |

### 10.4 Shared Buffers, Event Storage, and Data Custody

| ID | Responsibility allocation |
|---|---|
| PBIO-MEM-001 | RTL-024 shall own one centralized logical shared-buffer service for the SPI client and buffered functions allocated by the Architecture Specification, including storage realization, arbitration, client-range enforcement, service response, and shared-service error evidence. |
| PBIO-MEM-002 | RTL-017 through RTL-022 and RTL-024's internal SPI client shall own their Architecture-defined queue or mailbox semantics, pointers, occupancy, entry-valid state, backpressure, overflow, underflow, drop, and client-level evidence while using only their assigned shared-buffer segments. |
| PBIO-MEM-003 | The Architecture Specification shall solely own shared-buffer capacity, segment map, client interface, arbitration policy, service timing, reset behavior, visibility rules, and technology-independent memory semantics. |
| PBIO-MEM-004 | A shared-buffer client shall not instantiate or access a private duplicate of storage assigned to the centralized service and shall not access another client's segment. |
| PBIO-MEM-005 | RTL-005 shall own the Revision A event store, its local storage realization, event arbitration, retention, retrieval state, and overflow evidence as the sole functional-storage exception outside the centralized shared-buffer service. |
| PBIO-MEM-006 | Technology-specific memory wrappers or macros shall be owned by the applicable platform integration owner and shall preserve the Architecture-defined logical storage contract. |
| PBIO-MEM-007 | RTL-001 and each functional module shall own only module state, counters, snapshots, staging state, and other nonshared storage allocated by the Architecture and Register Map Specifications. |
| PBIO-MEM-008 | The external host software owner shall own long-term storage, nonvolatile configuration, archival retention, maintenance history, and disposition of data after host retrieval. |
| PBIO-MEM-009 | Host retrieval shall not transfer ownership of on-device capture, loss evidence, or state-change behavior and shall alter on-device state only through Register Map-defined side effects or commands. |

## 11. External Logical-Interface Ownership

The table below assigns responsibility at each Dragon Core external logical interface class. Exact interface populations, signal names, direction, timing, encodings, and safe values are owned by the SRS and Architecture Specification.

| Interface class | Producer | Consumer | Logical/protocol owner | Physical owner | Error owner | Verification owner |
|---|---|---|---|---|---|---|
| Functional clock input | External clock source through platform wrapper | RTL-024 clock integration | Architecture-defined Dragon Core clock integration | Platform/wrapper and board clock owners on their respective sides | Source owner for source validity; RTL-024 for defined internal clock evidence | Integration verification; external clock-source verification |
| Power-on reset input | OpenFrame or FPGA/board reset source through technology wrapper | RTL-024 reset integration | Architecture-defined Dragon Core reset integration | Platform/wrapper reset owner | Source owner for physical assertion; RTL-024 for defined qualification and reset evidence | Integration and RDC verification |
| SPI command path | External host SPI master | RTL-024 SPI target | External host for master behavior; Dragon Core for target behavior and internal conversion | Host, board, pad, and wrapper owners on their respective sides | Each protocol endpoint for errors assigned by the SRS; Dragon Core for on-device evidence | Host-interface and system verification |
| SPI response path | RTL-024 SPI target | External host SPI master | Dragon Core for response behavior; external host for compliant reception | Host, board, pad, and wrapper owners on their respective sides | Dragon Core for response generation; host for reception and host-side timeout handling | Host-interface and system verification |
| Host interrupt | Dragon Core interrupt aggregation through RTL-024 | External host interrupt receiver | Dragon Core for generation; host for reception and service | Pad/wrapper and board/host owners on their respective sides | Dragon Core for on-device interrupt evidence; host for missed-service evidence external to the device | Interrupt, integration, and host-system verification |
| GPIO | RTL-006 and external digital source through RTL-024 | External digital load and RTL-006, according to configured direction | Dragon Core for logical GPIO behavior; external integrator for attached equipment behavior | Board/aircraft integrator and applicable wrapper owner | Dragon Core for defined logical errors; external integrator for electrical faults | GPIO, integration, and external-interface verification |
| Rotor and engine pulse inputs | Conditioned external pulse source | RTL-024 input adapter and allocated monitor | Dragon Core for digital capture and monitor use; external integrator for source and conditioning | Board or aircraft integrator | External integrator for sensor/conditioning faults; Dragon Core for defined digital timeout, qualification, and measurement evidence | Monitor, CDC, integration, and equipment-interface verification |
| General pulse/frequency inputs | Conditioned external pulse source | RTL-024 input adapter and allocated measurement function | Dragon Core for digital capture and measurement use; external integrator for source and conditioning | Board or aircraft integrator | External integrator for source/conditioning faults; Dragon Core for defined digital evidence | Measurement, CDC, integration, and equipment-interface verification |
| Health/discrete inputs | Conditioned external comparators or supervisors | RTL-024 input adapter and health-monitor function | Dragon Core for digital capture and supervision; external integrator for health-source meaning and conditioning | Board or aircraft integrator | External integrator for external sensing faults; Dragon Core for defined digital fault evidence | Health, CDC, integration, and equipment-interface verification |
| Sampled sensor-value ingress | External host or authorized internal message producer | Sensor-monitor function | Producer for value representation at its output; Dragon Core for acceptance and monitoring behavior | Owner of the transport by which the value enters | Producer for source validity; Dragon Core for defined stale, invalid, and threshold evidence | Sensor, routing/host, and system verification |
| ARINC 429 receive | External ARINC line receiver | RTL-024 digital receive adapter and RTL-017 | External board for electrical reception; Dragon Core for digital timing recovery, framing, and receive-function use | Board or aircraft integrator | External board for physical-layer faults; Dragon Core for defined adapter, parity, framing, overrun, and receive evidence | ARINC interface, integration, and system verification |
| ARINC 429 transmit | RTL-018 through RTL-024 | External ARINC line driver | Dragon Core for digital word acceptance and transmit-control behavior; external board for electrical transmission | Board or aircraft integrator | Dragon Core for defined digital transmit evidence; external board for physical line faults | ARINC interface, integration, and system verification |
| Classical CAN | External CAN transceiver and RTL-019 | RTL-019 and external CAN transceiver | Dragon Core for controller protocol; external board for transceiver and physical bus | Board or aircraft integrator | Dragon Core for controller-state and defined transceiver-error evidence; external board for physical faults | CAN interface, integration, and system verification |
| UART | External UART source and RTL-020 | RTL-020 and external UART receiver | Dragon Core for digital UART protocol; external equipment for its endpoint behavior | Board or aircraft integrator | Dragon Core for defined framing, parity, overrun, and buffer evidence; external owner for remote-end faults | UART interface, integration, and system verification |
| Logical safety outputs | RTL-016 through RTL-024 | External safety-driver circuitry | Dragon Core for authorized logical command and safe logical state; external integrator for energy-control behavior | Board or aircraft integrator | Dragon Core for defined logical safety evidence; external integrator for driver, load, and energy-control faults | Safety, integration, and external-driver verification |
| User logical I/O | RTL-022/RTL-023 and conditioned external user source through RTL-024 | Authorized internal function or external user load | Dragon Core for bounded logic and authorized routing; external integrator for attached equipment behavior | Board or aircraft integrator | Dragon Core for defined authorization and routing evidence; external integrator for physical faults | User-logic, routing, integration, and external-interface verification |
| Production-test interface | External test equipment and RTL-024 test integration | RTL-024 test integration and external test equipment | Dragon Core for bounded on-device test protocol; external test owner for equipment behavior | External test, board, pad, and wrapper owners on their respective sides | Dragon Core for authorization and on-device test errors; external test owner for equipment and fixture errors | Production-test, CDC/RDC, integration, and equipment verification |

No external interface transfers analog conditioning, electrical line-interface, power-drive, aircraft-control, application-policy, or long-term-storage ownership into the Dragon Core logical design.

## 12. Safety, User Logic, Test, and Security Responsibility

| ID | Responsibility allocation |
|---|---|
| PBIO-SAFE-001 | Dragon Core shall own the hardware safety-supervision responsibilities assigned by the SRS, including detection, persistence, classification, interlock, watchdog, lost-link, response authorization, logical output command, and required on-device evidence. |
| PBIO-SAFE-002 | RTL-016 shall be the sole internal owner of final logical safety-output command and gating; RTL-024 shall own only connection and logical pad adaptation between RTL-016 and the technology-wrapper boundary. |
| PBIO-SAFE-003 | The external safety-circuit owner shall own isolation, protection, power switching, relay or contactor drive, valve or actuator drive, aircraft-energy control, load monitoring, and final physical fail-safe implementation. |
| PBIO-SAFE-004 | External software, user logic, routing, test, debug, wrapper logic, and platform resources shall not become alternate owners or bypass paths for a safety responsibility allocated to Dragon Core. |
| PBIO-SAFE-005 | The board or aircraft integrator shall own aircraft hazard analysis, installation-specific response allocation, assurance, certification, operational authorization, and the final aircraft safety case. |
| PBIO-USER-001 | RTL-022 shall own only the bounded, fabrication-fixed user-logic behavior allocated by the Architecture Specification; the external host shall own permitted runtime selections and application interpretation. |
| PBIO-USER-002 | RTL-023 shall own only the finite authorized signal-routing behavior allocated by the Architecture Specification; RTL-021 shall own only the finite authorized message-routing behavior allocated there. |
| PBIO-USER-003 | User logic and routing shall not acquire ownership of clocks, resets, register protection, test authorization, logical safety outputs, or unrestricted external transmission. |
| PBIO-TEST-001 | RTL-024 and the applicable technology wrapper shall own the bounded production-test path, authorization boundary, functional isolation, safe logical disposition, test CDC/RDC, and on-device diagnostic evidence allocated by the Architecture Specification. |
| PBIO-TEST-002 | The external test owner shall own test equipment, fixture wiring, physical stimulus and capture, equipment timing, equipment-side protocol execution, and interpretation of captured data. |
| PBIO-TEST-003 | ASIC scan insertion and physical design-for-test structures shall be owned by the ASIC integration owner and shall not create an alternate functional interface or alter SRS-defined behavior. |
| PBIO-SEC-001 | Dragon Core shall own only the bounded hardware access-control and protected-operation mechanisms required by the SRS; their detailed behavior remains owned by the SRS, Architecture, and Register Map Specifications. |
| PBIO-SEC-002 | The external host and system owners shall own authentication, authorization policy, user identity, credential storage, software access control, secure external storage, network security, and physical access control unless a future product requirement explicitly reallocates one of those functions. |
| PBIO-SEC-003 | Platform identification, integrity checks, protected-write sequences, and test authorization shall not be interpreted as ownership of cryptographic identity, secure boot, key storage, or an on-device software trust boundary. |

## 13. External Data, Calibration, and Application Ownership

| ID | Responsibility allocation |
|---|---|
| PBIO-DATA-001 | The producer of a digital measurement shall own its source validity, sampling provenance, and representation at the producer boundary; Dragon Core shall own only the acceptance, processing, status, and evidence defined for that representation. |
| PBIO-DATA-002 | Sensor excitation, analog conversion, linearization, unit conversion, installation calibration, calibration storage, and calibration maintenance shall remain with the external sensor, board, aircraft, or software owner. |
| PBIO-DATA-003 | The board or aircraft integrator shall own physical message-bus connection, external endpoint compatibility, bus loading, termination, wiring, and installation-specific traffic policy. |
| PBIO-DATA-004 | The external application owner shall own the meaning assigned to retrieved events, measurements, status, faults, and diagnostic evidence beyond the fixed representations defined by the SRS, Architecture, and Register Map Specifications. |
| PBIO-DATA-005 | Retrieval, acknowledgement, or clearing performed by the host shall not transfer ownership of the hardware condition that produced the data and shall not substitute software records for on-device evidence required by the SRS. |

## 14. Verification Responsibility at Ownership Boundaries

Verification responsibility follows the ownership assignments in this specification; exact verification methods, environments, cases, coverage, evidence, and outcomes remain solely with the Verification Plan.

| ID | Verification responsibility allocation |
|---|---|
| PBIO-VER-001 | Producer verification shall establish correctness of the producer's output values, validity, stability, sequencing, and error indications through its boundary. |
| PBIO-VER-002 | Consumer verification shall establish compliant acceptance, interpretation, response, and backpressure at the consumer boundary. |
| PBIO-VER-003 | Integration verification shall establish connection, direction, width, type, endpoint mapping, tie-offs, clock/reset context, wrapper correspondence, and absence of bypass paths. |
| PBIO-VER-004 | CDC/RDC verification shall establish the Architecture-defined crossing structure, reset interaction, reconvergence discipline, constraints, and end-to-end data integrity. |
| PBIO-VER-005 | Platform verification shall establish correctness of technology wrappers and preservation of the common Dragon Core logical wrapper contract. |
| PBIO-VER-006 | Board or equipment verification shall establish electrical compatibility, conditioning, transceiver behavior, protection, signal integrity, loading, wiring, and equipment-side protocol behavior. |
| PBIO-VER-007 | System verification shall establish SRS-defined externally observable behavior across the combined producer, consumer, integration, and physical boundaries. |
| PBIO-VER-008 | Host-system verification shall establish host-master behavior, interrupt service, software use of the register contract, legal configuration, retrieval, persistence, and recovery responsibilities. |
| PBIO-VER-009 | ASIC physical verification shall establish the future ASIC Integration Specification's platform, package, pad, power, timing, test, and physical-implementation responsibilities without redefining logical behavior. |
| PBIO-VER-010 | A verification environment shall not compensate for, conceal, or waive an undefined or nonconforming responsibility at an ownership boundary. |

## 15. Required Interface Ownership Record

Every external or internal interface defined by the Architecture Specification shall include, directly or by reference, one ownership record containing all of the following fields:

| Required field | Required content |
|---|---|
| Interface identifier | Stable Architecture-controlled identifier and purpose |
| Producer | Single producer or explicitly defined arbitration owner |
| Consumer | Single consumer or explicitly enumerated consumers |
| Logical owner | Owner of the interface's functional purpose and use |
| Physical owner | Owner of electrical or technology-specific realization, or `N/A` for an entirely internal logical interface |
| Protocol owner | Owner of transfer, handshake, sequencing, arbitration, timeout, and recovery |
| Error owner | Owner of detection, evidence, reporting, and recovery for each error class |
| Connection owner | Owner of direction, width, type, mapping, tie-off, clock/reset association, and integration |
| Verification owner | Verification scope responsible for each assigned aspect under the Verification Plan |

The Architecture Specification shall own the interface's signals, data representation, width, encodings, clock and reset context, handshake, timing, CDC/RDC mechanism, error behavior, reset behavior, disabled behavior, and safe behavior. A blank, implicit, shared-without-partition, or conflicting ownership field is not permitted.
