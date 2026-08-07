# Dragon Core Verification Plan

- **Document ID:** RCA-DFC-VP-002
- **Product:** Dragon Core Revision A
- **Program:** Dragon Flight Core ASIC Development Program
- **Organization:** Royal Cubit Aerospace
- **Purpose:** Define the verification methods, environments, cases, coverage, required outcomes, and evidence definitions used to demonstrate conformity of Dragon Core Revision A.

## 1. Purpose and Scope

This Verification Plan is the sole normative owner of the verification subjects assigned by `RCA-DFC-CHTR-002`, Section 3. It defines how the Dragon Core Revision A technical specification set and its derived RTL, generated artifacts, platform realizations, and fabricated-device behavior are checked.

Verification is requirements based. Expected results shall be derived from the technical fact's normative owner and shall not create an alternate requirement, design, register, coding, or responsibility definition. A conflict, ambiguity, omission, unreachable specified behavior, or untestable specified behavior shall be corrected in its owning specification before the affected verification result can pass.

This plan covers specification consistency, generated-data consistency, RTL conformance, module and integration verification, formal proof, clock/reset-domain analysis, FPGA validation, hardware-in-the-loop testing, selected OpenFrame integration inputs, gate-level behavior, and post-silicon testing. Physical ASIC selections owned by the future ASIC Integration Specification are verified only when those selected inputs exist; this plan does not select them.

Aircraft certification, aircraft-level safety assessment, external analog qualification, external power-drive behavior, application software correctness, and installation-level assurance remain outside the Dragon Core verification boundary assigned by `RCA-DFC-PBIO-002`.

## 2. Normative Language and Source Rules

The terms **shall** and **shall not** identify mandatory verification obligations. **May** identifies a permitted method or evidence form. The word **pass** identifies a test or analysis result that satisfies every stated required outcome.

This plan applies `CHTR-DOC-001` through `CHTR-DOC-007` and does not repeat the Charter's technical-authority table. Verification shall use:

- `RCA-DFC-CHTR-002` for product mission, scope, selected platforms, external-host model, and fixed constraints;
- `RCA-DFC-PBIO-002` for boundary and verification responsibility;
- `RCA-DFC-SRS-002` for externally observable requirements;
- `RCA-DFC-ARCH-002` for internal contracts, allocations, interfaces, states, priorities, types, clocks, resets, CDC/RDC, and logical wrapper behavior;
- `RCA-DFC-REG-002` for host-visible registers and field semantics;
- `RCA-DFC-RTL-STD-002` for SystemVerilog implementation rules; and
- `RCA-DFC-RTM-002` for relationships among existing identifiers.

The RTM shall map every SRS requirement to one or more verification-case identifiers defined here. It shall not redefine a case's method or required outcome.

## 3. Verification Principles

| ID | Mandatory verification principle |
|---|---|
| VP-GEN-001 | Every verification activity shall use a unique `VP-*` case identifier from this plan. |
| VP-GEN-002 | Every SRS requirement shall map to at least one case whose method can establish its complete required behavior. |
| VP-GEN-003 | Every Architecture contract, Register Map field contract, and applicable RTL Coding Standard rule shall have downstream verification evidence. |
| VP-GEN-004 | Expected behavior shall come from the normative owner; a testbench, reference model, prior RTL implementation, waveform, or platform template shall not become an independent oracle. |
| VP-GEN-005 | Every executable test shall be self-checking and shall produce an unambiguous pass or fail outcome. Visual waveform inspection may supplement but shall not be the sole outcome criterion. |
| VP-GEN-006 | Negative verification shall exercise malformed, reserved, prohibited, unauthorized, out-of-range, unaligned, busy, timeout, overflow, underflow, abort, truncation, and simultaneous conditions wherever applicable. |
| VP-GEN-007 | A negative case passes only when the specified evidence is produced and every prohibited functional side effect is absent. |
| VP-GEN-008 | Every finite resource shall be exercised at empty, one-entry, near-full, full, overflow or rejection, recovery, minimum, and maximum boundaries as applicable. |
| VP-GEN-009 | Reset shall be tested while idle and during every state-changing protocol phase. Module, safety-domain, system, SPI-domain, test-domain, and platform reset effects shall be distinguished. |
| VP-GEN-010 | Every specified simultaneous-condition priority shall be tested, asserted, or proven; newly detected sticky evidence shall dominate a simultaneous clear where required. |
| VP-GEN-011 | Safety, authorization, protocol conservation, ownership, exclusion, and finite-state invariants shall receive formal proof whenever the property is finite and tool-observable. |
| VP-GEN-012 | Randomized testing shall record its seed, shall use a scoreboard independent of DUT state, and shall supplement rather than replace directed boundary cases. |
| VP-GEN-013 | FPGA, gate-level, and ASIC evidence shall be compared at the same technology-independent logical interfaces used by RTL simulation. |
| VP-GEN-014 | A tool return code, warning suppression, code-coverage value, or demonstration alone shall not establish conformity. |
| VP-GEN-015 | Specified behavior that is unreachable or cannot be objectively verified shall be corrected in the owning specification; it shall not be silently excluded. |

## 4. Verification Scopes

`V0` through `V6` identify concurrent evidence scopes. They are not sequential phases or administrative controls.

| Scope | Name | Content |
|---|---|---|
| V0 | Specification and generated-data consistency | Identifier integrity, source ownership, cross-references, trace completeness, numeric consistency, and generated-artifact agreement |
| V1 | Module verification | Independent compile, lint, synthesis, simulation, assertion, formal, reset, boundary, and error verification of RTL-001 through RTL-024 |
| V2 | Domain integration | Infrastructure, monitoring, safety, databus, routing, user, shared-resource, and production-test interactions |
| V3 | Full-core integration | RTL-024 assembly, host path, registers, operating state, interrupts, events, faults, safety, pads, clocks, resets, and cross-domain behavior |
| V4 | FPGA validation | ECP5 realization with the VisionFive 2 validation host and controlled digital fixtures |
| V5 | Hardware-in-the-loop and external digital interfaces | Representative host, adapter, protocol-analyzer, signal-source, load, and fault-fixture behavior at defined digital boundaries |
| V6 | ASIC integration and fabricated-device verification | Selected OpenFrame integration inputs, structural and timing checks, gate-level behavior, post-silicon logical behavior, and characterization |

Evidence from one scope may satisfy a case in another scope only when the case explicitly permits that method and the observed boundary is equivalent.

## 5. Verification Method Codes

Only the following method codes shall appear in the RTM and case results.

| Code | Method | Required content |
|---|---|---|
| I-SPEC | Specification inspection | Controlled-source comparison, identifier/reference checks, and an explicit consistency outcome |
| I-RTL | RTL or netlist inspection | Structural source, hierarchy, connectivity, generated-data, wrapper, or netlist examination |
| A-CALC | Technical analysis | Stated inputs, units, equations, assumptions, bounds, tolerances, and computed outcome |
| A-CDC | CDC/RDC structural analysis | Crossing classification, structure, reset behavior, reconvergence, constraints, and tool report |
| A-SYN | Compile, lint, elaboration, synthesis, timing, or equivalence analysis | Reproducible source/configuration, reviewed diagnostics, structural outcome, and applicable constraints |
| T-SIM | Self-checking RTL or gate-level simulation | Directed or randomized stimulus, independent expected model, assertions, and pass/fail result |
| F-PROP | Formal property proof | Property, assumptions, reachable-state basis, proof result, and bounded-depth justification when bounded |
| T-FPGA | FPGA execution | Identified FPGA image, host/fixture configuration, measured logical behavior, and comparison with simulation |
| T-HIL | Hardware-in-the-loop execution | Identified host/device/fixture configuration, injected conditions, captures, and pass/fail comparison |
| T-IF | External digital-interface conformance test | Protocol or signal source/analyzer configuration, digital-boundary captures, and conformance outcome |
| T-FI | Controlled fault injection | Injected fault, injection point, expected evidence, prohibited side effects, recovery, and result |
| T-GLS | Gate-level simulation | Identified netlist and timing mode, reset/initialization or selected functional scenario, and comparison with RTL |
| T-ASIC | Fabricated-device test | Device/build identity, board/fixture configuration, measurements, expected behavior, and result |

## 6. Verification Environments

| ID | Environment | Principal elements and use |
|---|---|---|
| EV-01 | Specification consistency environment | Canonical specifications, identifier extractors, Markdown/reference checkers, and RTM consistency tools |
| EV-02 | Generated-data consistency environment | Machine-readable architecture/register sources, package/header generators, schema validators, and byte/field comparators |
| EV-03 | Compile, lint, and elaboration environment | At least one controlled SystemVerilog compiler/elaborator plus an independent parser or lint engine |
| EV-04 | Module simulation environment | Isolated DUT, BFMs, assertions, reference model, scoreboard, functional coverage, and fault controls |
| EV-05 | Formal environment | Module or composition harnesses, proof engines, reachable reset constraints, and property coverage |
| EV-06 | Domain integration simulation | Domain top, participating modules, shared services, scoreboards, randomized contention, and backpressure |
| EV-07 | Full-core simulation | RTL-024, all child modules, SPI model, DRI monitor, register model, protocol models, and external logical-pad models |
| EV-08 | CDC/RDC analysis environment | Structural CDC/RDC tools, crossing inventory, synchronizer/reconvergence checks, reset analysis, and constraints |
| EV-09 | Synthesis and netlist environment | Generic and selected target synthesis, hierarchy/resource reports, equivalence where used, timing constraints, and GLS netlists |
| EV-10 | ECP5 FPGA validation environment | ECP5 platform, technology wrapper, VisionFive 2 host, instrumentation, and controlled digital fixtures |
| EV-11 | Hardware-in-the-loop environment | Host software, FPGA or ASIC device, representative digital adapters, analyzers, signal sources, loads, and fault injection |
| EV-12 | Protocol conformance environment | ARINC, CAN, UART, SPI, pulse, GPIO, health, and logical-safety digital-boundary analyzers and generators |
| EV-13 | Selected OpenFrame integration environment | Selected OpenFrame release and future ASIC Integration Specification inputs, physical tools, wrapper, pads, macros, constraints, and reports |
| EV-14 | Gate-level environment | Post-synthesis or post-layout netlist, SDF modes when available, reset sources, and logical-interface scoreboards |
| EV-15 | Post-silicon environment | Fabricated device, validation board, VisionFive 2 or conforming host, instrumentation, fixtures, and build-identification data |

## 7. Required Common Verification Components

| Component | Mandatory behavior |
|---|---|
| Independent SPI model | Generates every SRS/Architecture-defined command and response phase, CRC, word count, wait-fill, abort point, truncation point, status, and timing boundary without reusing DUT CRC or framing logic |
| DRI monitor | Checks request stability, acceptance, one-outstanding behavior, exact response conservation, commit timing, deadline, and absence of late side effects |
| Generated register model | Derives every offset, field, access class, reset, legal value, protection rule, read behavior, side effect, and priority from the Register Map machine-readable source |
| Operating-state model | Predicts state, qualifiers, readiness, reset scope, and priority from SRS and Architecture inputs |
| Interrupt scoreboard | Predicts raw, latched, pending, acknowledged, cleared, vector, priority, and host-interrupt behavior |
| Timestamp model | Predicts raw phase/ticks, snapshots, signed offset arithmetic, correlation validity, overflow evidence, and simultaneous-command priority |
| Event scoreboard | Predicts pending slots, arbitration, records, ordering, snapshot/pop/clear, overwrite, source loss, store overflow, coalescing, and nonrecursive diagnostic events |
| Fault and safety scoreboard | Predicts active/latched sources, classification, recoverability, primary selection, request lanes, authorization, latching, inhibit, clear, and logical outputs |
| Shared-buffer model | Predicts owner ranges, arbitration, request/response timing, client pointers/occupancy, complete-entry visibility, reset invalidation, and error evidence |
| Protocol reference models | Independently predict ARINC, CAN, UART, canonical messages, routing filters, replication, arbitration, backpressure, drops, and error encodings |
| Production-test model | Predicts authorization, command collection, capture, shift, loopback, deauthorization, CDC/RDC handshakes, and output-enable state |
| Coverage collector | Records requirement, case, state, transition, field, encoding, priority, boundary, assertion, proof, code, and platform coverage without changing DUT behavior |

## 8. Reproducibility and Result Records

Every case result shall record the case identifier, methods actually used, controlling source identifiers, source and generated-artifact content hashes, tool and library versions, command/configuration, parameters and compile definitions, random seed when applicable, hardware image or fabricated-device build identity when applicable, raw evidence location, and the observed result.

A result is **PASS** only when every required outcome in the case is satisfied. Any unmet required outcome is **FAIL**. A run prevented by an invalid environment or missing evidence is not a case result and shall be rerun after correction. Tool warnings shall be reviewed individually; blanket suppression is prohibited.

## 9. Specification and Generated-Consistency Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-CONS-001 | V0 | I-SPEC | EV-01 | The complete canonical specification set and document identifiers match `RCA-DFC-CHTR-002`, Section 3; no staging prefix or alternate active document identity exists. |
| VP-CONS-002 | V0 | I-SPEC | EV-01 | Every normative identifier is unique, every cited identifier resolves to its owner, and every section/appendix/table reference resolves. |
| VP-CONS-003 | V0 | I-SPEC | EV-01 | Every SRS category is contiguous and its population arithmetic equals the SRS total; every requirement appears exactly once in the RTM. |
| VP-CONS-004 | V0 | I-SPEC | EV-01 | Each Architecture contract has upstream justification and at least one downstream verification allocation; no Architecture or verification-case identifier is orphaned. |
| VP-CONS-005 | V0 | I-SPEC | EV-01 | Every Register Map field traces to an SRS requirement or Architecture contract, or is explicitly Architecture-derived; every field's cited identifier resolves. |
| VP-CONS-006 | V0 | I-SPEC | EV-01 | No duplicated normative definition, undefined shorthand method, unresolved placeholder, competing allocation, or unresolved technical ambiguity remains in the technical specification set. |
| VP-CONS-007 | V0 | I-SPEC, A-CALC | EV-01 | Logical port counts, widths, directions, producer/consumer links, pad population, and Appendix A connectivity reconcile mechanically. |
| VP-CONS-008 | V0 | I-SPEC, A-CALC | EV-01, EV-02 | All Appendix B packed structures are gap-free and overlap-free; declared widths equal computed widths, including the Architecture-defined safety-control structure. |
| VP-CONS-009 | V0 | I-SPEC, A-CALC | EV-01, EV-02 | Register offsets are aligned and unique, fields cover each word without overlap or omission, reset values are legal, and packed-structure mappings reconcile. |
| VP-CONS-010 | V0 | I-SPEC, A-CALC | EV-01, EV-02 | Shared-buffer segments exactly cover the Architecture-defined address space without overlap, gap outside the defined reserved segment, or capacity mismatch. |
| VP-CONS-011 | V0 | I-SPEC, A-CALC | EV-01, EV-02 | Interrupt, event, fault, safety-response, message-source, message-destination, interlock-term, user-route, and test-vector numeric allocations are unique and internally consistent. |
| VP-CONS-012 | V0 | I-SPEC, A-SYN | EV-02 | Generated packages, host definitions, verification model, and manifests reproduce their normative machine-readable sources exactly and fail generation on every Register Map Section 33 invalidity. |
| VP-CONS-013 | V0 | I-SPEC | EV-01 | Every verification case identifier in this plan is unique, every method and environment code is defined, and the RTM contains no undefined case, method, module, or register-field identifier. |
| VP-CONS-014 | V0 | I-SPEC | EV-01 | PBIO producer, consumer, physical owner, protocol owner, error owner, and verification owner records exist for every external and internal interface class required by `CHTR-TECH-016`. |

## 10. RTL Conformance, Static, and Synthesis Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-RTL-001 | V1, V3 | A-SYN | EV-03 | Every controlled source compiles and elaborates without error in the primary environment and an independent parser or lint engine. |
| VP-RTL-002 | V1, V3 | A-SYN | EV-03 | No implicit net, unintended width conversion, ambiguous signedness, unsupported construct, or incomplete assignment remains. |
| VP-RTL-003 | V1, V3 | I-RTL, A-SYN | EV-03 | Each state-holding object has one procedural owner; no unintended latch, combinational loop, internal tri-state, unresolved driver, or multiple driver exists. |
| VP-RTL-004 | V1, V3 | I-RTL, A-SYN | EV-03, EV-09 | RTL-024 instantiates RTL-001 through RTL-023 exactly once and child-to-child connectivity exists only through Architecture-defined internal nets. |
| VP-RTL-005 | V1, V3 | I-RTL, A-SYN | EV-03, EV-09 | Functional RTL is technology independent; technology primitives and physical resources occur only in Architecture/PBIO-defined wrappers. |
| VP-RTL-006 | V1, V3 | I-RTL, A-SYN | EV-03, EV-09 | No processor, software runtime, processor memory, unrestricted internal bus, or field-programmable fabric is present. |
| VP-RTL-007 | V1, V3 | I-RTL, A-SYN | EV-03 | Generated constants, types, registers, interrupts, events, and version definitions are imported from their generated packages; copied local numeric authorities are absent. |
| VP-RTL-008 | V1, V3 | I-RTL, A-SYN | EV-03, EV-09 | Client modules instantiate no private queue storage and access centralized storage only through the Architecture-defined typed service; RTL-005 is the sole event-store exception. |
| VP-RTL-009 | V1, V3 | I-RTL, A-SYN | EV-03, EV-09 | Clock-enable logic is synchronous, no functional RTL-generated clock exists, and clock/reset use matches Architecture Sections 4 and Appendix E. |
| VP-RTL-010 | V1 | I-RTL, A-SYN | EV-03 | FSM encodings, default behavior, illegal-state handling, priority, and reset values conform to Architecture contracts and the RTL Coding Standard. |
| VP-RTL-011 | V1, V3 | A-SYN | EV-09 | Generic and selected target synthesis complete without unintended storage, asynchronous feedback, unsupported construct, or unconstrained functional clock. |
| VP-RTL-012 | V3, V6 | A-SYN, T-GLS | EV-09, EV-14 | Equivalence or selected post-synthesis comparisons preserve register-visible, safety, reset, protocol, and shared-resource behavior. |
| VP-RTL-013 | V1, V3 | I-RTL | EV-03 | Assertions exist for valid/ready stability, exact-once acceptance, response conservation, range protection, legal states, set/clear priority, and prohibited paths where applicable. |
| VP-RTL-014 | V1, V3 | A-SYN | EV-03, EV-09 | Simulation/formal-only source is absent from synthesis file lists and no synthesis directive changes required functional behavior. |
| VP-RTL-015 | V1, V3 | A-SYN | EV-03, EV-09 | A clean build from controlled sources regenerates all required inputs and produces identical generated definitions and technology-independent RTL content. |
| VP-RTL-016 | V1, V3 | I-RTL, A-SYN | EV-03, EV-09 | All applicable mandatory RTL Coding Standard rules have a recorded conforming check; ambiguity is returned to the owning specification rather than resolved locally in RTL. |

## 11. Clock, Reset, CDC, and RDC Cases

The crossing inventory and mechanisms are owned by Architecture Appendix E. Assumptions shall describe only behavior guaranteed by the applicable source/interface owner.

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-CDC-001 | V1, V3 | A-CDC | EV-08 | Every clock and reset crossing is classified, matches one Appendix E entry, and uses its specified synchronizer, mailbox, toggle, qualifier, or reset mechanism. |
| VP-CDC-002 | V1, V3 | A-CDC, F-PROP | EV-05, EV-08 | No independently synchronized multibit payload, unsafe reconvergence, unclassified asynchronous control, or combinational asynchronous path into host-visible or safety state exists. |
| VP-CDC-003 | V1, V3 | F-PROP, T-SIM | EV-05, EV-07 | `CDC-001` transfers each complete validated SPI request at most once, holds payload stable, and creates no DRI activity for an aborted ownership state. |
| VP-CDC-004 | V1, V3 | F-PROP, T-SIM | EV-05, EV-07 | `CDC-002` transfers each complete core response at most once, holds payload stable through acknowledgement, and never shifts a stale response into a later frame. |
| VP-CDC-005 | V1, V3 | A-CDC, F-PROP, T-SIM | EV-05, EV-07, EV-08 | `CDC-TEST-001` qualifies authorization and transfers only a complete stable command; deauthorization flushes ownership and prevents execution. |
| VP-CDC-006 | V1, V3 | A-CDC, F-PROP, T-SIM | EV-05, EV-07, EV-08 | `CDC-TEST-002` transfers one atomic diagnostic snapshot; all capture bits remain stable until acknowledged and do not reconverge independently. |
| VP-CDC-007 | V1, V3 | A-CDC, F-PROP, T-SIM | EV-05, EV-07, EV-08 | `CDC-TEST-003` transfers one stable completion/result object and flushes it without stale status on reset or deauthorization. |
| VP-CDC-008 | V1, V3 | A-CDC, F-PROP, T-SIM | EV-05, EV-07, EV-08 | `RDC-TEST-001` asserts reset and removes TEST_DATA output enable without requiring TEST_CLK; release occurs only after authorization and specified synchronization. |
| VP-CDC-009 | V1, V3 | A-CDC, F-PROP, T-SIM | EV-05, EV-07, EV-08 | `RDC-001` and `RDC-002` assert asynchronously, release by their Architecture mechanisms, tolerate stopped SPI_SCLK, and cannot expose partially reset state. |
| VP-CDC-010 | V1, V3 | T-SIM, F-PROP | EV-05, EV-07 | Reset during every request, response, buffer, queue, commit, event, interrupt, fault, and production-test phase produces the Architecture Appendix F state and no late side effect. |
| VP-CDC-011 | V3, V4, V6 | A-CDC, T-FPGA, T-ASIC | EV-08, EV-10, EV-15 | Asynchronous logical inputs satisfy the specified synchronization/qualification behavior and show no platform-dependent functional difference. |
| VP-CDC-012 | V1, V3 | A-CDC | EV-08 | CDC/RDC constraints cover asynchronous clock groups, synchronizer placement, recovery/removal, mailbox payload stability, reconvergence, and all specified false-path or exception endpoints without overbroad masking. |

## 12. SPI Host Transport and DRI Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-HOST-001 | V1, V3 | T-SIM, T-IF | EV-04, EV-07, EV-12 | SPI Mode, bit/byte order, SCLK range, MISO phase, and chip-select framing match `DFC-INTF-0012` through `DFC-INTF-0016` and `ARCH-SPI-001`. |
| VP-HOST-002 | V1, V3 | T-SIM | EV-04, EV-07 | Every SRS-defined numeric opcode, legal word count, and command length executes in address order; every other opcode, reserved count bit, and invalid length rejects without target side effect. |
| VP-HOST-003 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Command and response CRC use the SRS-defined numeric parameters and coverage boundaries; every single-bit corruption and every byte-boundary corruption is detected. |
| VP-HOST-004 | V1, V3 | T-SIM | EV-04, EV-07 | Every defined SPI status is produced for its cause, success is produced only after complete success, and reserved statuses are unreachable. |
| VP-HOST-005 | V1, V3 | T-SIM | EV-04, EV-07 | Response fill count, marker, status, completed count, reserved byte, optional read data, and CRC match the SRS/Architecture for success and every failure position. |
| VP-HOST-006 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | CS_N deassertion at every pre-acceptance bit position produces no DRI request or target side effect, clears transaction authorization, updates only specified abort evidence, and leaves last accepted result unchanged. |
| VP-HOST-007 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | CS_N deassertion at every post-acceptance response position may truncate shifting but never rolls back a completed write; terminal result and truncation evidence remain correct. |
| VP-HOST-008 | V1, V3 | T-SIM | EV-04, EV-07 | Multiword execution stops on the first failing word; earlier successful words remain committed, later words do not execute, and completed count is exact. |
| VP-HOST-009 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | One accepted command produces at most one DRI request per word and exactly one definitive transaction status. |
| VP-HOST-010 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | DRI request and response fields remain stable while stalled, at most one transaction is outstanding, and exactly one response follows each accepted request. |
| VP-HOST-011 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Every DRI completion code maps to the required SPI status; the reserved DRI code is never emitted and is handled safely if injected. |
| VP-HOST-012 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | RTL-001 commits a write only with the same-cycle OK response; timeout produces no late response, late write, or untracked state change. |
| VP-HOST-013 | V1, V3 | T-SIM | EV-04, EV-07 | Alignment, decode, access, reserved, range, protection, busy, and endpoint failures follow the Architecture-defined first-error order and preserve unrelated state. |
| VP-HOST-014 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Protected authorization expires, is consumed, or clears exactly as specified under success, failure, pre-acceptance abort, post-acceptance truncation, timeout, reset, and back-to-back commands. |
| VP-HOST-015 | V1, V3 | T-SIM | EV-04, EV-07 | Before host-ready, a complete frame returns BUSY and creates no DRI request or target side effect. |
| VP-HOST-016 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | The reset-release quiet interval and CS_N-to-first-edge qualification accept at the exact legal boundaries and reject every shorter interval without DRI activity. |
| VP-HOST-017 | V1, V3 | T-SIM, A-CALC | EV-04, EV-07 | DRI completion or timeout and full SPI response satisfy all SRS performance bounds at minimum and maximum supported SCLK rates and with maximum permitted wait fill. |
| VP-HOST-018 | V3, V4, V5, V6 | T-IF, T-FPGA, T-HIL, T-ASIC | EV-10, EV-11, EV-12, EV-15 | End-to-end host transactions produce the same DRI requests, register effects, result evidence, tri-state behavior, timing, and CRC on simulation, FPGA, HIL, and fabricated-device boundaries. |

## 13. Register-Contract Cases

The generated register model shall exercise every field defined by `RCA-DFC-REG-002`; sampling may not substitute for complete field coverage.

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-REG-001 | V1, V3 | T-SIM | EV-04, EV-07 | Every implemented offset is aligned, readable or rejectable as defined, and produces the exact reset/read value; every unimplemented address returns the defined decode result. |
| VP-REG-002 | V1, V3 | T-SIM | EV-04, EV-07 | Every RW field accepts its minimum, maximum, representative legal values, and required cross-field combinations; every illegal/reserved value rejects atomically. |
| VP-REG-003 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Every live RO and constant field reports its source/constant, ignores no prohibited write silently, and produces the specified access error for an illegal write. |
| VP-REG-004 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Every bitwise W1C field clears only written active bits; new same-cycle evidence dominates clear and unrelated bits remain unchanged. |
| VP-REG-005 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Every whole-counter clear treats zero as no action, all ones as one complete clear pulse, and every other value as access error; a same-cycle qualifying increment follows the Register Map priority. |
| VP-REG-006 | V1, V3 | T-SIM | EV-04, EV-07 | Every WO-command and W1S field produces one defined command/action, rejects illegal values, reads as specified, and does not repeat without a new accepted write. |
| VP-REG-007 | V1, V3 | T-SIM | EV-04, EV-07 | Every reserved-zero field reads zero, rejects a written one atomically, and produces no side effect. |
| VP-REG-008 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Staged objects preserve active state until validation/commit; success replaces the complete object atomically and failure preserves both prior active and staged contents while retaining the first error. |
| VP-REG-009 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Snapshot reads are coherent and nondestructive; pop removes exactly the snapped oldest object; empty, stale-snapshot, and invalid pop/snapshot operations reject without pointer change. |
| VP-REG-010 | V1, V3 | T-SIM | EV-04, EV-07 | Every selector accepts only defined indices, changes no selected object, and returns exact active/staged readback for the selected object. |
| VP-REG-011 | V1, V3 | T-SIM | EV-04, EV-07 | Protected fields reject absent, expired, malformed, or consumed authorization and accept exactly one authorized operation as specified. |
| VP-REG-012 | V1, V3 | T-SIM | EV-04, EV-07 | Host abort evidence, response-truncation evidence, last accepted result, address, completed count, and sequence are mutually consistent for every transaction outcome. |
| VP-REG-013 | V1, V3 | T-SIM | EV-04, EV-07 | Timestamp enable reads constant one; event overwrite-oldest reads constant one; neither can be cleared or treated as a writable policy. |
| VP-REG-014 | V1, V3 | T-SIM | EV-04, EV-07 | Signed sensor values, thresholds, hysteresis, source, and sequence fields preserve exact two's-complement and metadata semantics across host read/write and routed updates. |
| VP-REG-015 | V1, V3 | T-SIM | EV-04, EV-07 | Safety authorization rejects every reserved source bit, accepts every legal combination, and active polarity occupies the Architecture-defined packed member and register field. |
| VP-REG-016 | V1, V3 | T-SIM | EV-04, EV-07 | Every legal and reserved UART, CAN, ARINC, routing, interlock, test, source, destination, flag, error, and command encoding receives the specified accept/reject behavior. |
| VP-REG-017 | V1, V3 | T-SIM | EV-04, EV-07 | External/system reset and every module/safety reset produce the exact per-field persistence, clear, constant, safe-state, pointer, command, and snapshot behavior of Register Map Section 32 and Architecture Appendix F. |
| VP-REG-018 | V0, V1, V3 | I-SPEC, T-SIM | EV-01, EV-02, EV-04, EV-07 | Generated SystemVerilog, host definitions, verification data, and documentation agree exactly for every offset, field, access class, reset, legal predicate, side effect, priority, and packed mapping. |

## 14. Infrastructure Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-INF-001 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Operating-state reset, startup, normal, degraded, faulted, and test behavior follows `ARCH-STATE-001` through `ARCH-STATE-007`, including exact priority and reserved-state handling. |
| VP-INF-002 | V1, V3 | T-SIM | EV-04, EV-07 | Host-ready, initialization, observation, and effective-operational-enable qualifiers satisfy the SRS/Architecture equations independently of the primary state encoding. |
| VP-INF-003 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Mandatory and optional readiness, startup timeout, degraded acknowledgement, fault latching, and reset-command priority produce the required state and evidence. |
| VP-INF-004 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Interrupt RAW, LATCH, PENDING, ACKED, CLEAR, enable, priority, vector, and host IRQ equations hold for each implemented source, every reserved source, and all simultaneous set/clear/ack combinations. |
| VP-INF-005 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Raw timestamp starts at reset value and advances continuously after qualified release; host control cannot stop it. |
| VP-INF-006 | V1, V3 | T-SIM, A-CALC | EV-04, EV-07 | Timestamp phase, first tick, subsequent ticks, snapshot instant, signed offset arithmetic, modulo result, update sequence, correlation validity, overflow/underflow evidence, and simultaneous-command priority match `ARCH-TIME-001` through `ARCH-TIME-006`. |
| VP-INF-007 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Each event producer pending slot conserves complete stable records, reports source-slot loss, and cannot overwrite its pending record before acceptance. |
| VP-INF-008 | V1, V2, V3 | T-SIM | EV-04, EV-06, EV-07 | Event arbitration gives required diagnostic priority, rotates ordinary producers fairly, accepts at most one record per clock, and preserves record/source ordering. |
| VP-INF-009 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Event store push, pop, snapshot, clear, simultaneous push/pop, full overwrite, head/tail/level, and reset behavior match `ARCH-EVT-004` through `ARCH-EVT-008`. |
| VP-INF-010 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Store overflow and source-slot overflow schedule their Architecture-defined diagnostic events with the priority, coalescing, and loss-count behavior of `ARCH-EVT-001` through `ARCH-EVT-003`. |
| VP-INF-011 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Internally generated overflow records never recursively increment a source/store overflow counter or schedule another overflow report solely because the diagnostic record meets full storage. |
| VP-INF-012 | V1, V2, V3 | I-RTL, A-SYN, T-SIM | EV-03, EV-04, EV-06, EV-07, EV-09 | RTL-005 event storage is implemented as the Architecture-defined register-array exception and is not aliased to centralized shared-buffer storage. |
| VP-INF-013 | V1, V2, V3 | T-SIM | EV-04, EV-06, EV-07 | GPIO synchronization, qualification, input readback, direction/output gating, route combination, safe reset, and independent edge/level event and interrupt masks match `ARCH-MON-001`. |
| VP-INF-014 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Module and system reset cancel pending host/proxy commands and apply Architecture Appendix F state effects before any ordinary state progression. |
| VP-INF-015 | V2, V3 | T-SIM | EV-06, EV-07 | Simultaneous host traffic, interrupt sources, event producers, fault requests, reset requests, and queue backpressure preserve all specified priorities and evidence. |

## 15. Centralized Shared-Buffer Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-BUF-001 | V0, V1, V3 | I-SPEC, I-RTL, A-SYN | EV-01, EV-03, EV-09 | The service exists once inside RTL-024, every Architecture-defined client connects through its typed request/response channel, and no unrestricted storage bypass exists. |
| VP-BUF-002 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Each client can access every legal relative word in its assigned segment and cannot access another client's or the reserved segment; rejected access changes no storage or client state. |
| VP-BUF-003 | V1, V2, V3 | T-SIM | EV-04, EV-06, EV-07 | Reserved-segment reads and writes return the exact Architecture-defined results and never disclose prior physical contents. |
| VP-BUF-004 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Request fields remain stable until acceptance, each client has at most one outstanding request, response fields remain stable until acceptance, and each accepted request produces exactly one response. |
| VP-BUF-005 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | At most one request is accepted per CORE_CLK and rotating round-robin arbitration satisfies the Architecture-defined continuous-eligibility bound for every client and phase offset. |
| VP-BUF-006 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Every legal no-fault request receives OK within the Architecture/SRS latency bound; each protocol, range, and internal error returns its exact code. |
| VP-BUF-007 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | A partial multiword entry is never visible: all entry words commit before client valid/tail advancement, and readers cannot issue entry reads before owner-valid state. |
| VP-BUF-008 | V1, V2, V3 | T-SIM | EV-04, EV-06, EV-07 | Every Architecture-defined entry layout preserves word order, reserved zeros, metadata, timestamps, sequence, flags, and canonical message bits. |
| VP-BUF-009 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Each client owns and correctly updates its pointers, occupancy, ordering, backpressure, full/empty response, drop/overflow evidence, and simultaneous push/pop behavior. |
| VP-BUF-010 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Module reset invalidates only the selected client's state and cancels its request; system reset invalidates all client state and resets arbitration; a canceled response has no later effect. |
| VP-BUF-011 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Uninitialized or reset physical words are never observable until valid state authorizes them; absence of architectural ECC/parity does not create an alternate host-visible behavior. |
| VP-BUF-012 | V3, V4, V6 | A-SYN, T-FPGA, T-ASIC | EV-09, EV-10, EV-13, EV-15 | Inferred, FPGA, and selected ASIC storage wrappers preserve the same logical request, response, range, latency, reset, and complete-entry-visibility contract. |

## 16. Monitoring and Health Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-MON-001 | V1, V2 | T-SIM, A-CALC | EV-04, EV-06 | Rotor and engine period-mode equations, count-mode equations, rounding, saturation, pulses-per-revolution, mode-transition hysteresis, and numeric limits match `ARCH-MON-002` through `ARCH-MON-005`. |
| VP-MON-002 | V1, V2, V4, V5 | T-SIM, T-FPGA, T-IF | EV-04, EV-06, EV-10, EV-12 | Rotor and engine inputs at SRS minimum, nominal, maximum, transition, noise-filter, missing-edge, and timeout boundaries meet accuracy/update requirements. |
| VP-MON-003 | V1, V2 | T-SIM, A-CALC | EV-04, EV-06 | Both pulse/frequency channels independently satisfy edge qualification, period/count equations, Q17.15 rounding, saturation, update, threshold, hysteresis, and timeout behavior. |
| VP-MON-004 | V1, V2, V4, V5 | T-SIM, T-FPGA, T-IF | EV-04, EV-06, EV-10, EV-12 | Concurrent pulse channels at all SRS range and timing boundaries remain independent and meet accuracy/update requirements. |
| VP-MON-005 | V1, V2 | T-SIM | EV-04, EV-06 | Threshold entry and exit occur at the exact low/high/hysteresis boundaries, including saturated bound arithmetic and a new estimate's same-cycle comparison. |
| VP-MON-006 | V1, V2 | T-SIM, F-PROP | EV-04, EV-05, EV-06 | Sampled-sensor value, low, high, and hysteresis comparisons exercise the complete signed representation and the negative, zero, positive, minimum, maximum, and saturated-bound cases defined by `ARCH-MON-006`. |
| VP-MON-007 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | A host or routed sensor update atomically replaces value, valid, source, sequence, and age; host wins a same-cycle conflict and no mixed record is observable. |
| VP-MON-008 | V1, V2 | T-SIM | EV-04, EV-06 | Sensor age starts at zero, increments/saturates on millisecond ticks, applies the exact stale boundary, and treats zero maximum age as disabled. |
| VP-MON-009 | V1, V2 | T-SIM | EV-04, EV-06 | Sensor low, high, stale, and invalid event/interrupt subconditions are independently masked and produce exact source, sequence, flags, and evidence. |
| VP-MON-010 | V1, V2, V4, V5 | T-SIM, T-FPGA, T-IF | EV-04, EV-06, EV-10, EV-12 | Every health input satisfies synchronization, polarity, stable-time qualification, active, sticky, recovery pulse, aggregate fault, and qualification-failure behavior. |
| VP-MON-011 | V1, V2 | T-SIM, F-PROP | EV-04, EV-05, EV-06 | New active health evidence dominates clear, recovery does not clear sticky evidence, and the aggregate fault equals the registered OR of enabled active channels. |
| VP-MON-012 | V1, V2, V3 | T-FI, T-SIM | EV-04, EV-06, EV-07 | Missing, extra, noisy, stuck, stale, out-of-range, and invalid monitored inputs produce only their specified events, interrupts, faults, and recovery behavior. |

## 17. Safety-Domain Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-SAFE-001 | V1, V2, V3 | F-PROP, I-RTL | EV-05, EV-09 | RTL-016 is the sole logical safety-output producer; no host, route, user, test, debug, protocol, or child-module bypass path reaches a safety pad. |
| VP-SAFE-002 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Reset, startup, initialization failure, disable, global inhibit, observation, TEST_DEBUG, production-test operation, invalid state, and safety-domain reset force each applicable logical safety output inactive. |
| VP-SAFE-003 | V1, V2, V3, V4, V5, V6 | T-SIM, T-FPGA, T-HIL, T-ASIC | EV-04, EV-06, EV-07, EV-10, EV-11, EV-15 | No production-test command, loopback, injection, or diagnostic state can activate a safety output; test observations use only diagnostic paths. |
| VP-SAFE-004 | V1, V2 | T-SIM | EV-04, EV-06 | Watchdog service at each key/window boundary, early, late, invalid, missing, timeout, recovery, disable, reset, and simultaneous timeout/service condition matches `ARCH-SAFE-005` and `ARCH-RTL012-001`. |
| VP-SAFE-005 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | All fixed fault sources, reserved sources, class values, recoverability, active/latched masks, primary selection, degraded/fault state, response request, clear, and reassertion behavior match Architecture Section 10.1 and Appendix C.6. |
| VP-SAFE-006 | V1, V2 | T-SIM | EV-04, EV-06 | Each interlock term, inversion, operator, guard, response mask, and reserved value is validated; COMMIT_ALL is atomic, retains first error, and evaluates the new bank at the specified time. |
| VP-SAFE-007 | V1, V2 | T-SIM, F-PROP | EV-04, EV-05, EV-06 | Each interlock expression and violation source produces the exact guard and safety request; violation qualification takes effect without a prohibited one-cycle output window. |
| VP-SAFE-008 | V1, V2 | T-SIM | EV-04, EV-06 | Every lost-link activity identifier, reserved identifier, qualification interval, timeout boundary, recovery interval, disable, reset, and simultaneous natural/injected condition matches `ARCH-SAFE-007` and `ARCH-SAFE-008`. |
| VP-SAFE-009 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | All Architecture-defined safety-response positions are exercised: each legal producer/source mapping reaches only its assigned mask position and every reserved position is tied inactive and rejected in configuration. |
| VP-SAFE-010 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | For each safety channel, authorized active requests OR by requested response bit; simultaneous requests cannot cancel one another. |
| VP-SAFE-011 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Active polarity, request latching, recovery, host clear, channel disable, inhibit, and new-request priority match Architecture Section 10.4 and `ARCH-RTL016-001`. |
| VP-SAFE-012 | V1, V2, V3 | T-FI, T-SIM | EV-04, EV-06, EV-07 | Combined watchdog, fault, interlock, and lost-link requests preserve source evidence, output priority, interrupt/event behavior, and safe recovery. |
| VP-SAFE-013 | V1, V2, V3 | F-PROP, T-FI | EV-05, EV-06, EV-07 | Every prohibited safety-affecting access, mask bit, route, command, reserved encoding, and unqualified injection is rejected without output or active-configuration change. |
| VP-SAFE-014 | V4, V5, V6 | T-FPGA, T-HIL, T-ASIC | EV-10, EV-11, EV-15 | Logical safety-output timing, polarity, reset inactivity, request response, inhibit, and fault combinations match simulation at the documented digital boundary using externally safe fixtures. |

## 18. Databus and Canonical Routing Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-BUS-001 | V1, V2 | T-SIM, T-IF | EV-04, EV-06, EV-12 | ARINC receive accepts every legal speed/word/parity form, attaches exact metadata/timestamp/sequence, and reports parity, gap/framing, adapter, disabled, overflow, and shared-buffer errors. |
| VP-BUS-002 | V1, V2 | T-SIM, T-IF | EV-04, EV-06, EV-12 | ARINC transmit validates speed, gap, parity controls, queue state, and serialization; completion, rejection, underrun, adapter, disabled, and shared-buffer evidence are exact. |
| VP-BUS-003 | V1, V2 | T-SIM, T-IF | EV-04, EV-06, EV-12 | CAN 2.0A/B standard/extended identifiers, DLC, RTR, data, bit timing, arbitration, stuffing, errors, error confinement, listen-only, loopback, bus-off, and recovery match Architecture Section 11.4. |
| VP-BUS-004 | V1, V2 | T-SIM, T-IF | EV-04, EV-06, EV-12 | UART divisor, baud, parity, stop bits, RX/TX framing, break, overrun, underflow, disable completion, and reset abort match Architecture Section 11.4 and Register Map encodings. |
| VP-BUS-005 | V1, V2, V3 | T-SIM | EV-04, EV-06, EV-07 | Each protocol RX/TX queue preserves capacity, order, complete-entry visibility, timestamp/metadata, full/empty, simultaneous push/pop, host versus route priority, and loss evidence. |
| VP-BUS-006 | V1, V2 | T-SIM | EV-04, EV-06 | Every canonical message source/destination, message type, payload length, flag, metadata, timestamp, and reserved encoding accepts or rejects exactly as Architecture Section 11.1 defines. |
| VP-BUS-007 | V1, V2 | T-SIM, F-PROP | EV-04, EV-05, EV-06 | All source/destination pairs in the fixed authorization matrix are exhaustively checked; legal pairs can be selected and prohibited pairs cannot become active. |
| VP-BUS-008 | V1, V2 | T-SIM | EV-04, EV-06 | All routing entries validate source, nonzero destination mask, message-type mask, filter fields, flags, fixed authorization, duplicate conflict, and reserved fields with exact first-error code. |
| VP-BUS-009 | V1, V2 | T-SIM, F-PROP | EV-04, EV-05, EV-06 | Route validation/commit atomically replaces all active entries and an in-flight record completes under its captured configuration epoch. |
| VP-BUS-010 | V1, V2, V3 | T-SIM | EV-04, EV-06, EV-07 | Ingress range checking, route-entry order, type/source/filter evaluation, destination de-duplication, and no-match/filter-mismatch evidence follow `ARCH-ROUTE-001` through `ARCH-ROUTE-008`. |
| VP-BUS-011 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | A required full destination backpressures only when drop-on-full is clear; when set, that copy drops with exact evidence while independent copies proceed. |
| VP-BUS-012 | V1, V2 | T-SIM, F-PROP | EV-04, EV-05, EV-06 | Each destination arbitrates eligible ingress records by rotating round-robin, advances only on a committed copy, and cannot starve a continuously eligible source. |
| VP-BUS-013 | V1, V2 | T-SIM | EV-04, EV-06 | Active route readback uses the Architecture/Register Map source and destination widths; upper reserved bits remain zero and no alternate identifier width is exposed. |
| VP-BUS-014 | V1, V2 | T-SIM | EV-04, EV-06 | Every route commit error and runtime `LAST_ERROR` encoding is produced for its cause; all reserved encodings remain ungenerated and reject safely if presented. |
| VP-BUS-015 | V2, V3 | T-SIM, T-FI | EV-06, EV-07 | Concurrent maximum legal ingress, replication, destination stalls, host access, events, interrupts, and resets preserve message order, committed copies, counts, and first-error evidence. |
| VP-BUS-016 | V4, V5, V6 | T-FPGA, T-HIL, T-IF, T-ASIC | EV-10, EV-11, EV-12, EV-15 | ARINC, CAN, UART, and routed-message behavior at the digital boundary matches the simulation reference for legal traffic, timing limits, concurrency, and injected errors. |

## 19. User Logic and User-Configurable Routing Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-USER-001 | V1, V2, V3 | I-RTL, F-PROP | EV-03, EV-05, EV-07 | RTL-022 Revision A operational equations are fixed and inert: user outputs and enables, transmitted-message valid, and operational event/interrupt/fault outputs remain inactive in every reachable state. |
| VP-USER-002 | V1, V2 | T-SIM | EV-04, EV-06 | Each nonzero functional parameter, enable attempt, or operational output request is rejected with defined violation evidence and no active-state change. |
| VP-USER-003 | V1, V2, V3 | T-SIM | EV-04, EV-06, EV-07 | Synchronized user inputs and route/message inputs are observable only through defined diagnostic state and never influence an operational output. |
| VP-USER-004 | V1, V2 | T-SIM, F-PROP | EV-04, EV-05, EV-06 | RTL-022 input/output diagnostic mailboxes obey the capacity, complete-entry visibility, full/empty, push/pop, reset, ordering, and no-operational-action rules of `ARCH-BUF-011` and `ARCH-ULI-003`. |
| VP-USER-005 | V1, V2 | T-SIM | EV-04, EV-06 | User-route staging accepts every legal source/destination/mode/enable combination and rejects every unauthorized, reserved, conflicting, duplicate-exclusive, or malformed entry. |
| VP-USER-006 | V1, V2 | T-SIM, F-PROP | EV-04, EV-05, EV-06 | User-route validation/commit is atomic across the complete staged bank; rejection preserves prior active routes and reports the exact first error. |
| VP-USER-007 | V1, V2 | T-SIM, F-PROP | EV-04, EV-05, EV-06 | Exact source/destination authorization, exclusivity, wired-OR, active polarity, level/edge behavior, disable behavior, and activation priority match Architecture Section 13.2. |
| VP-USER-008 | V1, V2, V3 | F-PROP, T-FI | EV-05, EV-06, EV-07 | User routes cannot reach safety, clocks, resets, protected writes, host transport control, test authorization, direct transmitter control, or any undefined internal endpoint. |
| VP-USER-009 | V1, V2 | T-SIM | EV-04, EV-06 | Edge history updates and gating prevent a stale edge on re-enable; reset/disable/commit/input simultaneity follows `ARCH-RTL023-001`. |
| VP-USER-010 | V3, V4, V6 | T-SIM, T-FPGA, T-ASIC | EV-07, EV-10, EV-15 | RTL-022 remains inert and user-route logical outputs match simulation across platform realizations and reset/test states. |

## 20. Production-Test Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-TEST-001 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | Physical authorization qualifies only after the Architecture-defined interval; deauthorization immediately removes TEST_DATA output enable and deterministically clears active command state. |
| VP-TEST-002 | V1, V3 | T-SIM | EV-04, EV-07 | Qualified test-active requires all Architecture-defined authorization/control conditions and is the sole test-active state reported to RTL-002 and status. |
| VP-TEST-003 | V1, V3 | T-SIM | EV-04, EV-07 | A test command executes only after one complete command word in the specified serial order while authorization remains active. |
| VP-TEST-004 | V1, V3 | T-SIM | EV-04, EV-07 | CAPTURE, SHIFT, and SAFE_LOOPBACK accept every legal argument boundary and reject every reserved opcode, reserved argument bit, malformed length, unauthorized, and busy condition. |
| VP-TEST-005 | V1, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-07 | CAPTURE atomically samples every Architecture-defined diagnostic-vector allocation without modifying the sampled functional state. |
| VP-TEST-006 | V1, V3 | T-SIM | EV-04, EV-07 | SHIFT uses the bit order and exact requested length of `ARCH-TEST-006`, reports the exact shifted count/result, and leaves TEST_DATA high impedance outside the output phase. |
| VP-TEST-007 | V1, V3 | T-SIM | EV-04, EV-07 | Every defined loopback selection reaches only its internal or fixture-safe endpoints; disabled and reserved selections produce no loopback action. |
| VP-TEST-008 | V1, V2, V3 | T-SIM, F-PROP | EV-04, EV-05, EV-06, EV-07 | Test interrupt/fault/activity injection is distinguishable, permitted only when authorized, cannot suppress natural evidence, and cannot directly command an operational output. |
| VP-TEST-009 | V1, V3 | T-SIM, T-FI | EV-04, EV-07 | Reset or deauthorization at every command, capture, shift, result, and loopback phase terminates deterministically, preserves required evidence, and creates no stale later completion. |
| VP-TEST-010 | V1, V2, V3 | F-PROP, I-RTL | EV-05, EV-09 | No production-test path activates a safety output or bypasses protected configuration, routing authorization, register access, clock/reset control, or normal protocol ownership. |
| VP-TEST-011 | V3, V4, V5, V6 | T-SIM, T-FPGA, T-HIL, T-ASIC | EV-07, EV-10, EV-11, EV-15 | Command framing, capture vector, shift length/order, loopbacks, injection evidence, output-enable behavior, and deauthorization match across logical implementations. |
| VP-TEST-012 | V1, V3, V6 | A-CDC, T-GLS | EV-08, EV-14 | All production-test CDC/RDC structures and constraints pass their dedicated crossing cases and retain safe output-enable behavior in gate-level reset scenarios. |

## 21. Module Derivation Cases

Each module case supplements, and does not replace, the cross-cutting cases in Sections 9 through 20. Each case shall exercise the applicable Architecture port catalog, packed control/status structures, Appendix C allocations, Appendix D reset/readiness row, Appendix E crossings, Appendix F priority/validation contract, Register Map fields, event/interrupt/fault condition masks, and SRS allocations.

| Case ID | Module | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-MOD-001 | RTL-001 | T-SIM, F-PROP, A-SYN | EV-03, EV-04, EV-05 | DRI decode/commit, protected access, first-error retention, configuration storage, status collection, proxy/staging commands, sensor-route arbitration, reset, ready, fault, event, and interrupt behavior satisfy `ARCH-RTL001-001` and `ARCH-VAL-001`. |
| VP-MOD-002 | RTL-002 | T-SIM, F-PROP | EV-04, EV-05 | Startup, primary and orthogonal states, mandatory/optional readiness, enable distribution, controlled reset, degraded acknowledgement, timeout, illegal-state handling, and priorities satisfy `ARCH-RTL002-001` and `ARCH-VAL-002`. |
| VP-MOD-003 | RTL-003 | T-SIM, F-PROP | EV-04, EV-05 | Raw, latched, pending, acknowledged, cleared, enabled, vector, priority, aggregate IRQ, reserved-source, reset, and injection behavior satisfy `ARCH-RTL003-001` and `ARCH-VAL-003`. |
| VP-MOD-004 | RTL-004 | T-SIM, F-PROP, A-CALC | EV-04, EV-05 | Always-running time, divider phase, snapshot, signed correlation, overflow, sequence, reset, priority, ready, fault, event, and validation satisfy `ARCH-RTL004-001` and `ARCH-VAL-004`. |
| VP-MOD-005 | RTL-005 | T-SIM, F-PROP | EV-04, EV-05 | Producer arbitration, atomic records, register-array store, overwrite, snapshot, pop, clear, diagnostic-overflow priority/coalescing/nonrecursion, reset, ready, fault, and validation satisfy `ARCH-RTL005-001` and `ARCH-VAL-005`. |
| VP-MOD-006 | RTL-006 | T-SIM, F-PROP | EV-04, EV-05 | Synchronization, qualification, direction/output precedence, route combination, event/interrupt conditions, safe reset, disable, ready, fault, and validation satisfy `ARCH-RTL006-001` and `ARCH-VAL-006`. |
| VP-MOD-007 | RTL-007 | T-SIM, A-CALC | EV-04 | Rotor edge qualification, mode selection, arithmetic, rounding, saturation, timeout, thresholds, hysteresis, evidence, reset, and validation satisfy `ARCH-RTL007-001` and `ARCH-VAL-007`. |
| VP-MOD-008 | RTL-008 | T-SIM, A-CALC | EV-04 | Engine edge qualification, high-rate mode, arithmetic, rounding, saturation, timeout, thresholds, hysteresis, independence, evidence, reset, and validation satisfy `ARCH-RTL008-001` and `ARCH-VAL-008`. |
| VP-MOD-009 | RTL-009 | T-SIM, A-CALC | EV-04 | Both channels independently satisfy edge qualification, Q17.15 arithmetic, rounding, saturation, timeout, thresholds, hysteresis, simultaneous edges, evidence, reset, and `ARCH-VAL-009`. |
| VP-MOD-010 | RTL-010 | T-SIM, F-PROP | EV-04, EV-05 | Signed thresholds/hysteresis, atomic value/valid/source/sequence update, host priority, age/stale, independent evidence masks, reset, ready, fault, and validation satisfy `ARCH-RTL010-001` and `ARCH-VAL-010`. |
| VP-MOD-011 | RTL-011 | T-SIM, F-PROP | EV-04, EV-05 | Synchronization, polarity, qualification, active/sticky/recovered masks, aggregate fault, evidence, clear priority, reset, ready, and validation satisfy `ARCH-RTL011-001` and `ARCH-VAL-011`. |
| VP-MOD-012 | RTL-012 | T-SIM, F-PROP | EV-04, EV-05 | Watchdog enable, key, exact window boundaries, timeout, recovery, evidence, safety request, disable/reset priority, ready, fault, and validation satisfy `ARCH-RTL012-001` and `ARCH-VAL-012`. |
| VP-MOD-013 | RTL-013 | T-SIM, F-PROP | EV-04, EV-05 | Fixed fault allocation, class, recoverability, active/latched state, primary selection, degraded/fault state, response, evidence, injection, clear/reset priority, and validation satisfy `ARCH-RTL013-001` and `ARCH-VAL-013`. |
| VP-MOD-014 | RTL-014 | T-SIM, F-PROP | EV-04, EV-05 | All operators/terms/inversions/guards, whole-bank validation/commit, first error, evaluation timing, response sources, evidence, reset, ready, fault, and validation satisfy `ARCH-RTL014-001` and `ARCH-VAL-014`. |
| VP-MOD-015 | RTL-015 | T-SIM, F-PROP | EV-04, EV-05 | All activity mappings, qualification, absence timeout, recovery, evidence, response sources, injection restrictions, natural/injected priority, reset, and validation satisfy `ARCH-RTL015-001` and `ARCH-VAL-015`. |
| VP-MOD-016 | RTL-016 | T-SIM, F-PROP | EV-04, EV-05 | Legal source authorization, request ORing, polarity, latching, recovery, clear, inhibit, test/reset/disable priority, sole output ownership, ready, fault, and validation satisfy `ARCH-RTL016-001` and `ARCH-VAL-016`. |
| VP-MOD-017 | RTL-017 | T-SIM, T-IF, F-PROP | EV-04, EV-05, EV-12 | ARINC RX protocol intake, complete shared-buffer entry, queue/full/pop ordering, timestamp/metadata, host/route removal arbitration, evidence, reset, and validation satisfy `ARCH-RTL017-001` and `ARCH-VAL-017`. |
| VP-MOD-018 | RTL-018 | T-SIM, T-IF, F-PROP | EV-04, EV-05, EV-12 | ARINC TX validation, complete entry, host/route priority, timing/parity/serialization, dequeue, errors, evidence, reset, and validation satisfy `ARCH-RTL018-001` and `ARCH-VAL-018`. |
| VP-MOD-019 | RTL-019 | T-SIM, T-IF, F-PROP | EV-04, EV-05, EV-12 | CAN wire protocol, RX/TX complete entries, arbitration, error confinement, bus-off/recovery, queue priority, evidence, reset, and validation satisfy `ARCH-RTL019-001` and `ARCH-VAL-019`. |
| VP-MOD-020 | RTL-020 | T-SIM, T-IF, F-PROP | EV-04, EV-05, EV-12 | UART baud/framing/parity, atomic received byte/flags, TX priority and completion, disable/reset behavior, evidence, and validation satisfy `ARCH-RTL020-001` and `ARCH-VAL-020`. |
| VP-MOD-021 | RTL-021 | T-SIM, F-PROP | EV-04, EV-05 | Ingress, complete canonical records, whole-bank commit, captured epoch, filtering, replication, destination arbitration/backpressure/drop, errors, reset, and validation satisfy `ARCH-RTL021-001` and `ARCH-VAL-021`. |
| VP-MOD-022 | RTL-022 | T-SIM, F-PROP | EV-04, EV-05 | Inert operational equations, zero-only parameters, diagnostic inputs, complete mailbox entries, reset, shared-buffer error, prohibited outputs, ready, fault, and validation satisfy `ARCH-RTL022-001` and `ARCH-VAL-022`. |
| VP-MOD-023 | RTL-023 | T-SIM, F-PROP | EV-04, EV-05 | Exact authorization, full-bank commit, exclusivity, wired-OR, edge/level behavior, disable/gating, stale-edge prevention, errors, reset, and validation satisfy `ARCH-RTL023-001` and `ARCH-VAL-023`. |
| VP-MOD-024 | RTL-024 | T-SIM, F-PROP, A-SYN | EV-03, EV-05, EV-07, EV-09 | Complete child integration, logical wrapper, host bridge, reset, pad adapters, shared-buffer service, production test, readiness/fault equations, safe gates, and validation satisfy `ARCH-RTL024-001` and `ARCH-VAL-024`. |

## 22. Full-Core, Performance, and Capacity Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-INT-001 | V3 | I-RTL, A-SYN, T-SIM | EV-03, EV-07, EV-09 | RTL-024 wrapper ports exactly match Architecture Appendix A, all internal connectivity classes are complete, widths agree, reserved inputs are tied safely, and no functional port floats. |
| VP-INT-002 | V3 | T-SIM | EV-07 | Reset through host-ready, startup, normal operation, observation, degraded operation, faulted operation, and authorized test state produces exact state, qualifiers, module readiness, safe outputs, and host evidence. |
| VP-INT-003 | V3 | T-SIM | EV-07 | Host configuration followed by autonomous monitoring/safety operation continues without internal software or continuous host participation except where the SRS explicitly defines host activity. |
| VP-INT-004 | V3 | T-SIM, F-PROP | EV-05, EV-07 | Simultaneous interrupt, event, fault, safety request, host access, route traffic, and legal clears preserve all source evidence and aggregate outputs. |
| VP-INT-005 | V3 | T-SIM | EV-07 | System, module, safety-domain, SPI-domain, and test-domain resets during idle and traffic preserve exact reset scope and unrelated state. |
| VP-INT-006 | V3 | T-SIM | EV-07 | Adapter/protocol errors propagate to only the specified status, event, interrupt, fault, safety, and host-visible evidence paths and recover exactly as defined. |
| VP-INT-007 | V3 | T-SIM, A-CALC | EV-07 | Startup, host transaction, DRI, interrupt response, event handling, measurement update, timeout, watchdog, lost-link, shared-buffer, and routing performance satisfy every SRS timing bound at exact boundary values. |
| VP-INT-008 | V2, V3 | A-CALC, T-SIM | EV-06, EV-07 | Worst-case legal host, interface, event, interrupt, and route-replication traffic identifies every finite queue/service assumption and produces the specified backpressure, latency, margin, and observable loss response. |
| VP-INT-009 | V2, V3 | T-SIM | EV-06, EV-07 | Every queue, FIFO, mailbox, table, route bank, interlock bank, source vector, selector, counter, and snapshot mechanism reaches all finite boundaries without silent loss or undefined state. |
| VP-INT-010 | V3 | T-SIM, F-PROP | EV-05, EV-07 | Observational and test modes block every prohibited operational action while preserving specified diagnostics and evidence collection. |
| VP-INT-011 | V3 | T-SIM | EV-07 | The logical pad population, directions, reset values, tri-state controls, host interrupt, protocol adapters, GPIO, user I/O, and safety outputs match SRS Section 6 and Architecture Section 5. |
| VP-INT-012 | V3 | A-SYN, T-SIM | EV-07, EV-09 | The same technology-independent RTL and generated definitions support FPGA and ASIC wrappers without conditional functional behavior. |

## 23. Fault-Injection and Negative Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-FI-001 | V1, V3 | T-FI, T-SIM | EV-04, EV-07 | SPI opcode, length, count, alignment, address, CRC, timing, abort, truncation, timeout, and endpoint faults produce exact result/evidence and no prohibited side effect. |
| VP-FI-002 | V1, V3 | T-FI, T-SIM | EV-04, EV-07 | Protected-write key, expiry, consumption, repeated-use, reserved-write, and unauthorized test faults cannot change protected configuration or operational state. |
| VP-FI-003 | V1, V2, V3 | T-FI, T-SIM | EV-04, EV-06, EV-07 | Queue full, empty access, overflow, underflow, stalled response, dropped copy, and internal shared-buffer error produce exact counts/evidence and preserve valid entries. |
| VP-FI-004 | V1, V2, V3 | T-FI, T-SIM | EV-04, EV-06, EV-07 | Interrupt saturation, event producer loss, event-store overwrite, fault combinations, and evidence clear races preserve every required sticky indication and priority. |
| VP-FI-005 | V1, V2 | T-FI, T-SIM | EV-04, EV-06 | Missing, extra, noisy, stuck, stale, invalid, and out-of-range monitoring inputs produce exact qualification, timeout, threshold, fault, and recovery behavior. |
| VP-FI-006 | V1, V2, V3 | T-FI, T-SIM | EV-04, EV-06, EV-07 | Watchdog, fault-manager, interlock, and lost-link injected conditions remain distinguishable from natural conditions and cannot suppress natural safety evidence. |
| VP-FI-007 | V1, V2, V3 | T-FI, T-SIM | EV-04, EV-06, EV-07 | ARINC, CAN, UART, and routing malformed records and adapter/protocol errors cannot create unauthorized messages, partial entries, or unrelated state changes. |
| VP-FI-008 | V1, V3 | T-FI, A-CDC, T-SIM | EV-07, EV-08 | Reset skew, reset during transfer, stopped source clock, asynchronous phase variation, mailbox cancellation, and deauthorization preserve all CDC/RDC safety properties. |
| VP-FI-009 | V1, V2, V3 | T-FI, F-PROP | EV-05, EV-06, EV-07 | User-logic, user-route, and production-test attempts to access prohibited endpoints are structurally impossible or reject with defined evidence and no action. |
| VP-FI-010 | V1, V3 | T-FI, F-PROP | EV-05, EV-07 | Injected illegal FSM encodings, reserved enum values, and impossible source IDs enter the specified safe/error response and cannot activate a prohibited output. |

## 24. FPGA and Hardware-in-the-Loop Cases

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-FPGA-001 | V4 | A-SYN, T-FPGA | EV-09, EV-10 | The ECP5 build is reproducible, uses the technology-independent RTL, confines primitives to wrappers, and identifies all source/generated content. |
| VP-FPGA-002 | V4 | T-FPGA | EV-10 | VisionFive 2 reads identity and exercises every register block, access class, protected flow, command, interrupt, and host result through the conforming SPI path. |
| VP-FPGA-003 | V4 | T-FPGA, T-IF | EV-10, EV-12 | SPI timing, CRC, MISO high impedance, quiet interval, minimum/maximum SCLK, abort, truncation, timeout, and host-interrupt behavior match simulation. |
| VP-FPGA-004 | V4 | T-FPGA | EV-10 | Clock, reset, repeated reset, startup, timestamp, event, GPIO, shared-buffer, operating-state, and long-duration autonomous behavior match simulation. |
| VP-FPGA-005 | V4 | T-FPGA, T-IF | EV-10, EV-12 | Rotor, engine, pulse, health, GPIO, user input, and logical safety-output digital-boundary timing and qualification meet SRS requirements. |
| VP-FPGA-006 | V4 | T-FPGA, T-IF | EV-10, EV-12 | ARINC, CAN, UART, canonical routing, queueing, backpressure, and injected protocol errors match reference-model outcomes. |
| VP-FPGA-007 | V4 | T-FPGA, T-FI | EV-10 | Long-duration maximum legal traffic, supervision, counter saturation, event overwrite, loss reporting, and recovery produce no unexplained divergence or silent loss. |
| VP-HIL-001 | V5 | T-HIL | EV-11 | A conforming external host performs initialization, protected configuration, event retrieval, interrupt handling, diagnostics, and recovery without relying on on-device software. |
| VP-HIL-002 | V5 | T-HIL, T-IF | EV-11, EV-12 | Concurrent representative ARINC, CAN, UART, pulse, GPIO, health, user input, host interrupt, and logical safety-output signals match digital-boundary requirements. |
| VP-HIL-003 | V5 | T-HIL, T-FI | EV-11 | Communication, monitored-input, host-loss, watchdog, interlock, and combined fault injection produces exact autonomous supervision, evidence, safe output, and recovery. |
| VP-HIL-004 | V5 | T-HIL | EV-11 | Protocol/timing captures clearly separate Dragon Core digital behavior from external transceiver, analog, board, load, and aircraft behavior assigned outside the device. |

## 25. OpenFrame, Gate-Level, and Post-Silicon Cases

The future ASIC Integration Specification supplies the exact physical inputs consumed by this section. Passing these cases shall not change any logical contract in the canonical specification set.

| Case ID | Scope | Method | Environment | Required outcome |
|---|---|---|---|---|
| VP-ASIC-001 | V6 | I-SPEC, I-RTL | EV-13 | Selected OpenFrame wrapper, release, PDK, package/pad mapping, power domains, macros, scan structure, and constraints are identified by the future ASIC Integration Specification and preserve PBIO ownership and the RTL-024 logical wrapper. |
| VP-ASIC-002 | V6 | A-SYN | EV-13 | Synthesis, static timing, power, DRC, LVS, antenna, and other applicable physical checks meet the selected integration inputs without an unconstrained functional path or altered logical interface. |
| VP-ASIC-003 | V6 | A-SYN, I-RTL | EV-09, EV-13 | Memory and technology wrappers preserve centralized-buffer and event-store logical behavior; scan/test insertion creates no operational or safety bypass. |
| VP-ASIC-004 | V6 | T-GLS | EV-14 | Gate-level reset assertion/release, startup, SPI-domain quiet behavior, test deauthorization, MISO/TEST_DATA output enable, and logical safety-output inactivity match RTL. |
| VP-ASIC-005 | V6 | T-GLS | EV-14 | Selected host, register, interrupt, event, safety, databus, routing, and shared-buffer scenarios match RTL at the same logical boundary with applicable timing annotation. |
| VP-ASIC-006 | V6 | T-ASIC | EV-15 | Device identity, CORE_CLK, reset, SPI transport, DRI/register access, host interrupt, timestamp, events, and diagnostics satisfy their cases on fabricated devices. |
| VP-ASIC-007 | V6 | T-ASIC, T-IF | EV-12, EV-15 | GPIO, monitoring inputs, health, user inputs, ARINC, CAN, UART, routing, and logical safety outputs satisfy digital-boundary behavior and timing on fabricated devices. |
| VP-ASIC-008 | V6 | T-ASIC, T-FI | EV-15 | Fabricated-device watchdog, faults, interlocks, lost-link, safety authorization/inhibit, reset, production test, and prohibited-path behavior match simulation and FPGA evidence. |
| VP-ASIC-009 | V6 | T-ASIC, A-CALC | EV-15 | Characterized supported clock, SPI timing, interface timing, reset, and long-duration behavior meet every applicable SRS limit across the selected physical operating conditions. |

## 26. Coverage Requirements

### 26.1 Trace and Case Coverage

| Coverage ID | Mandatory outcome |
|---|---|
| VP-COV-001 | Every SRS requirement is represented exactly once in the RTM and maps to at least one defined verification case and exact method code. |
| VP-COV-002 | Every Architecture contract has upstream justification and at least one case capable of verifying it; every Architecture-owned port, state, transition, priority, allocation, type, protocol, and error code is covered. |
| VP-COV-003 | Every Register Map field has complete coverage of offset, bit position, reset, access class, legal values, reserved values, validation, read behavior, side effects, protection, and simultaneous-condition priority. |
| VP-COV-004 | Every applicable mandatory RTL Coding Standard rule is covered by inspection, automated static analysis, assertion, simulation, formal proof, synthesis, or an explicit combination. |
| VP-COV-005 | Every verification case is unique, is referenced by at least one requirement/design/rule or an explicitly Architecture-derived verification need, and has at least one result for each required implementation scope. |

### 26.2 Functional and Structural Coverage

| Coverage ID | Mandatory outcome |
|---|---|
| VP-COV-006 | Reachable specified states and reachable specified transitions achieve 100 percent functional coverage. |
| VP-COV-007 | Every specified simultaneous-condition priority is exercised or proven, including reset, disable/inhibit, commit/command, new input/evidence, clear, and ordinary progression. |
| VP-COV-008 | Every legal encoding is exercised or proven and every reserved/illegal encoding that can be presented at a boundary is rejected or safely handled exactly as specified. |
| VP-COV-009 | Every reset value, reset scope, reset assertion/release path, and reset-during-activity phase is exercised or proven. |
| VP-COV-010 | Every interrupt, event, fault, safety-response, message source/destination, route endpoint, interlock source, test command, loopback, and condition-mask bit is exercised or proven. |
| VP-COV-011 | Every finite resource is covered at empty, one, intermediate, near-full, full, simultaneous removal/addition, overflow/rejection, recovery, and reset states as applicable. |
| VP-COV-012 | Every specified error/status/last-error/result code is produced for its cause; every reserved output code remains unreachable. |
| VP-COV-013 | Every assertion is activated in at least one applicable trace or receives a proof-coverage result showing that its antecedent is reachable. |
| VP-COV-014 | Statement, branch, expression, toggle, and FSM code coverage is collected for synthesizable RTL; uncovered implementation logic is analyzed against owning contracts and corrected or proven structurally unreachable. |
| VP-COV-015 | Cross coverage includes source × destination, state × reset, state × fault, access class × result, command phase × abort/reset, queue level × push/pop, safety lane × source × response, and route policy × destination readiness. |

No exclusion may remove specified behavior from coverage. A structural code-coverage exclusion is permitted only for tool-inserted or mathematically unreachable defensive implementation logic when a formal or static analysis proves unreachability and the owning specification requires no reachable behavior there.

## 27. Evidence Requirements

Evidence shall be sufficient for an independent reviewer to reproduce the stimulus or analysis and determine the outcome without relying on undocumented interpretation.

| Evidence class | Required content |
|---|---|
| Specification/consistency report | Inputs and hashes, checker version, executed checks, resolved identifiers, and exact failures or pass result |
| Analysis report | Inputs, units, assumptions, equations, bounds, tolerances, computed values, and conclusion |
| Simulation result | Case, test name, seed, DUT/build identity, stimulus summary, assertion/scoreboard result, coverage contribution, log, and relevant waveform/capture |
| Formal result | Property text/identifier, assumptions, reset/reachability constraints, proof engine/version, proof status, depth if bounded, and coverage/reachability result |
| CDC/RDC result | Crossing inventory, classifications, mechanisms, reset behavior, reconvergence findings, constraint review, and tool report |
| Synthesis/netlist result | Source/build identity, tool/options, warnings, hierarchy/resources, clocks/resets, constraints, and equivalence or GLS linkage where applicable |
| FPGA/HIL/interface result | Hardware/image identity, host and fixture configuration, instrumentation, procedure, raw captures, measured values, comparison, and result |
| ASIC result | Device/build identity, board/fixture, environmental condition, instrumentation, procedure, raw measurements/captures, expected comparison, and result |

Nondestructive observation is required except when a case intentionally exercises a defined snapshot, pop, clear, command, injection, or production-test operation.

## 28. Failure Correction and Regression

A failed case shall identify the controlling requirement or contract, observed behavior, expected behavior, reproducible configuration, technical impact, corrected artifact, and regression set. A corrected defect shall rerun the failing case and every case affected through shared packages, interfaces, registers, clocks/resets, CDC/RDC, buffers, event/interrupt/fault paths, safety paths, platform wrappers, or generated artifacts.

An intermittent, seed-dependent, tool-dependent, or platform-dependent mismatch remains a failure until its cause is corrected and the required outcomes reproduce. When the failure exposes an ambiguity or omission, the normative owner shall be corrected before the implementation or testbench.

## 29. Required Verification Outcomes

Dragon Core Revision A satisfies this Verification Plan only when all of the following outcomes are true:

| Outcome ID | Required outcome |
|---|---|
| VP-OUT-001 | Every SRS requirement has a passing verification result through the RTM using only defined case and method identifiers. |
| VP-OUT-002 | Every Architecture contract, Register Map field, and applicable mandatory RTL Coding Standard rule has passing evidence. |
| VP-OUT-003 | Every case required for the implementation scopes being claimed has a reproducible PASS result; no required outcome is unmet. |
| VP-OUT-004 | All identifier, cross-reference, port, width, allocation, address, field, generated-data, and trace consistency cases pass. |
| VP-OUT-005 | All module, domain, full-core, reset, CDC/RDC, protocol, shared-resource, safety, negative, and platform-correspondence cases pass. |
| VP-OUT-006 | Coverage outcomes `VP-COV-001` through `VP-COV-015` are satisfied, including 100 percent of reachable specified states and transitions. |
| VP-OUT-007 | No failed safety property, unsafe reset state, prohibited path, late state-changing effect, silent loss, or unexplained simulation/platform mismatch remains. |
| VP-OUT-008 | All evidence contains the configuration, identity, inputs, methods, raw observations, and expected comparison required by Sections 8 and 27. |

These are technical verification outcomes, not program status, fabrication authorization, certification credit, or operational authorization.
