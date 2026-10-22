# Dragon Core Architecture Specification

- **Document ID:** RCA-DFC-ARCH-002
- **Product:** Dragon Core Revision A
- **Program:** Dragon Flight Core ASIC Development Program
- **Organization:** Royal Cubit Aerospace
- **Purpose:** Define the complete technology-independent internal architecture, module contracts, algorithms, states, priorities, internal interfaces, protocols, clocks, resets, CDC/RDC, shared types, numeric allocations, and logical wrapper for Dragon Core Revision A.

## 1. Purpose and Scope

This specification is the sole normative owner of the internal architecture subjects assigned by `RCA-DFC-CHTR-002`, Section 3. It converts the externally observable requirements in `RCA-DFC-SRS-002` into complete derivation contracts for RTL-001 through RTL-024 and the technology-independent Dragon Core logical wrapper.

The product mission and scope remain owned by the Charter; responsibility boundaries remain owned by `RCA-DFC-PBIO-002`; externally observable behavior remains owned by the SRS; host-visible registers remain owned by `RCA-DFC-REG-002`; SystemVerilog rules remain owned by `RCA-DFC-RTL-STD-002`; verification remains owned by `RCA-DFC-VP-002`; and trace relationships remain owned by `RCA-DFC-RTM-002`. This specification cites those owners and does not redefine their subjects.

This specification completes the device architecture needed by subordinate external-software specifications. It defines deterministic device initialization, active-configuration readback paths, host-transaction reconciliation, diagnostic retention, queue and mailbox service behavior, and recovery-visible state. It does not define external-software APIs, tasks, threads, locking, persistence formats, retry policy, installation configuration, maintenance workflow, or aircraft application policy.

The terms **shall** and **shall not** identify mandatory design contracts. **May** identifies a permitted implementation choice that preserves every mandatory contract.

## 2. Architecture Contract Conventions

| Contract ID | Architecture rule |
|---|---|
| ARCH-GEN-001 | Every Architecture contract is identified by an `ARCH-*` identifier. Appendix table rows inherit the identifier printed in their first column or enclosing heading. |
| ARCH-GEN-002 | RTL-024 is the Dragon Core technology-independent top-level module and shall instantiate RTL-001 through RTL-023 exactly once. |
| ARCH-GEN-003 | RTL-001 is the sole DRI endpoint and sole host-visible address decoder. No other module shall decode a host address. |
| ARCH-GEN-004 | RTL-001 through RTL-023 operate in CORE_CLK. Only the SPI shift engine and production-test shift logic operate in SPI_SCLK and TEST_CLK respectively. |
| ARCH-GEN-005 | Each module owns its functional state, local counters, sticky evidence, one event-pending slot, and output equations. Shared storage ownership follows Section 12. |
| ARCH-GEN-006 | Every counter identified as saturating increments to its all-ones value and remains there until its defined whole-counter clear or applicable reset. |
| ARCH-GEN-007 | For a whole-counter clear, `0x00000000` has no effect, `0xFFFFFFFF` produces one clear pulse, and every other value is rejected. True W1C masks remain bitwise. |
| ARCH-GEN-008 | Unless a more specific contract states otherwise, priority is: asynchronous reset assertion; synchronous module/reset action; disable or safety inhibit; accepted commit or command; newly detected condition; authorized clear; ordinary state progression. A newly detected sticky condition dominates a simultaneous clear of the same condition. |
| ARCH-GEN-009 | Reserved values, identifiers, bits, routes, sources, destinations, commands, and arguments produce no operational action. A configuration write containing a prohibited reserved one is rejected atomically. |
| ARCH-GEN-010 | `ready` means the module has completed reset initialization, has legal active configuration, and can perform its defined function. `fault` is the registered OR of the module's unmasked Architecture-defined local fault conditions. |
| ARCH-GEN-011 | `irq_req` is the registered OR of the module's enabled interrupt subconditions. `evt_valid` is asserted while the module event-pending slot is occupied, and the complete event record remains stable until accepted. |
| ARCH-GEN-012 | A module-local reset clears functional state, pending transfers, pointers, occupancy, sticky evidence, counters, snapshots, staged data, and one-shot commands owned by that module; it preserves configuration stored in RTL-001 unless the reset scope explicitly includes RTL-001. |
| ARCH-GEN-013 | A disabled optional module drives operational outputs inactive, accepts no new operational work, contributes no new ordinary event or interrupt, preserves its RTL-001 configuration, and reports not-ready without requesting degraded or faulted state. |
| ARCH-GEN-014 | Configuration validation occurs at the accepted write for a self-contained field and at the explicit commit for a staged object. Rejection preserves the prior active object and reports the first error in the priority defined for that object. |
| ARCH-GEN-015 | No internal protocol permits a partial record, partial message, partial shared-buffer entry, or independently changing multibit value to become valid. |
| ARCH-GEN-016 | A field identified as current state is combinational or registered present-state information and is never substituted for sticky historical evidence. A field identified as sticky evidence remains set until its explicit authorized clear or applicable reset. |
| ARCH-GEN-017 | A diagnostic clear acts only on the selected evidence bit or complete selected counter. It never clears an active source, an unrelated diagnostic class, an event-store record, an interrupt or fault latch owned by another function, or the host-reconciliation record. |
| ARCH-GEN-018 | When one occurrence feeds local status, fault aggregation, interrupt state, and event generation, every path uses the same Appendix C source identity. Clearing or servicing one path does not service another path unless an explicit contract states otherwise. |
| ARCH-GEN-019 | Every active configuration value is held in RTL-001 registered storage and is readable through its Register-Map-owned field. No active configuration, mode, route, policy, threshold, mask, or timing value depends on hidden state. |

## 3. Product Hierarchy and Module Decomposition

### 3.1 Technology Hierarchy

| Contract ID | Level | Element | Architecture responsibility |
|---|---:|---|---|
| ARCH-HIER-001 | 0 | OpenFrame or ECP5 platform wrapper | Technology-specific pads, clocks, resets, memories, test resources, and physical constraints as allocated by PBIO |
| ARCH-HIER-002 | 1 | ASIC or FPGA technology wrapper | Adapts platform resources to the invariant RTL-024 logical wrapper without changing its behavior |
| ARCH-HIER-003 | 2 | `dfc_dragon_core_top` / RTL-024 | Technology-independent external logical interface, child instantiation, internal connectivity, host bridge, adapters, centralized buffer service, reset integration, and bounded production test |
| ARCH-HIER-004 | 3 | RTL-001 through RTL-023 | Isolated functional modules connected only through the interfaces in Appendix A |

OpenFrame supplies no Dragon Core host bus, register decoder, management processor, software runtime, interrupt subsystem, event subsystem, or application controller. The exact OpenFrame release, PDK, package, physical pad assignment, power mapping, memory macro, scan structure, and physical timing constraints are inputs to the future ASIC Integration Specification identified by `RCA-DFC-CHTR-002`, Section 3.3.

### 3.2 Functional Modules

| Contract ID | Module | Function owned by module |
|---|---|---|
| ARCH-MOD-001 | RTL-001 Configuration Register Bank | DRI endpoint, address decode, protected access, configuration storage, staged/proxy register service, command generation, status collection, and first-error retention |
| ARCH-MOD-002 | RTL-002 System Control Logic | Startup, primary operating state, optional-module enables, controlled reset, readiness and degraded/fault coordination |
| ARCH-MOD-003 | RTL-003 Interrupt Controller | Fixed 32-position raw, pending, acknowledged, clear, priority, and aggregate interrupt processing |
| ARCH-MOD-004 | RTL-004 Timestamp Engine | Always-running raw microsecond time, snapshot, signed correlation offset, correlated time, and update sequence |
| ARCH-MOD-005 | RTL-005 Event Logger | 24-producer arbitration, 64 × 128-bit register-array event store, retrieval, overwrite-oldest, and overflow reporting |
| ARCH-MOD-006 | RTL-006 GPIO Controller | Eight synchronized/qualified bidirectional GPIO channels, direction and commanded/effective output state, edge/level conditions, events, and interrupts |
| ARCH-MOD-007 | RTL-007 Rotor RPM Monitor | Rotor edge qualification, RPM measurement, thresholds, timeout, events, interrupts, and fault request |
| ARCH-MOD-008 | RTL-008 Engine RPM Monitor | Engine edge qualification, RPM measurement, thresholds, timeout, events, interrupts, and fault request |
| ARCH-MOD-009 | RTL-009 Pulse/Frequency Measurement | Two qualified pulse inputs, Q17.15 frequency measurement, thresholds, timeout, events, interrupts, and fault request |
| ARCH-MOD-010 | RTL-010 Sensor Monitor Interface | Two signed sampled sensors, atomic updates, age/stale processing, thresholds, events, interrupts, and fault request |
| ARCH-MOD-011 | RTL-011 System Health Monitor | Eight qualified health inputs, qualification progress/failure, active/sticky/recovered state, aggregate health fault, events, and interrupts |
| ARCH-MOD-012 | RTL-012 Watchdog Manager | Protected service-window supervision, key checking, timeout/recovery evidence, and lane-0 safety request |
| ARCH-MOD-013 | RTL-013 Fault Manager | Fixed 17-source fault collection, classification, recoverability, primary selection, event/interrupt generation, and lane-1 safety request |
| ARCH-MOD-014 | RTL-014 Interlock Engine | Eight atomically committed four-term expressions, guarded-action permission, violation evidence, and lane-2 safety requests |
| ARCH-MOD-015 | RTL-015 Lost-Link Supervisor | Eight activity monitors, qualification, absence timeout, recovery, evidence, and lane-3 safety requests |
| ARCH-MOD-016 | RTL-016 Safety Output Controller | Sole generation and independently reported requested, latched, commanded, effective, and cause-inhibited state for four logical safety outputs |
| ARCH-MOD-017 | RTL-017 ARINC 429 Receive Interface | Predecoded word intake, receive queue state, timestamps, evidence, route-source conversion, and shared-buffer client state |
| ARCH-MOD-018 | RTL-018 ARINC 429 Transmit Interface | Ordered transmit queue state, parity/timing/serialization, evidence, route-destination conversion, and shared-buffer client state |
| ARCH-MOD-019 | RTL-019 Classical CAN Interface | CAN 2.0A/B state machine, error confinement, RX/TX queue state, canonical conversion, and shared-buffer client state |
| ARCH-MOD-020 | RTL-020 UART Interface | Full-duplex UART state machines, RX/TX queue state, canonical conversion, and shared-buffer client state |
| ARCH-MOD-021 | RTL-021 Databus Routing Engine | Five ingress slots, sixteen routes, destination replication, five destination queues, arbitration, backpressure, and shared-buffer client state |
| ARCH-MOD-022 | RTL-022 User Logic Island | Inert Revision A mask profile, diagnostic input capture, two four-word mailboxes, and shared-buffer client state |
| ARCH-MOD-023 | RTL-023 User-Configurable Routing | Sixteen staged signal-route entries, authorization, commit, edge/level processing, conflict detection, and exact destination combination |
| ARCH-MOD-024 | RTL-024 Dragon Core Top-Level Integration | Logical wrapper, all child instances and internal wires, SPI bridge and terminal reconciliation record, external adapters, shared-buffer service, clock/reset diagnostics, pad-safe gating, and production-test logic |

## 4. Operating State, Startup, Clock, and Reset

### 4.1 Primary Operating State

`dfc_operating_state_t` is encoded as follows. RTL-002 is its sole producer.

| Contract ID | State | Encoding | Entry and exit contract |
|---|---|---:|---|
| ARCH-STATE-001 | RESET_ACTIVE | `3'b000` | Active whenever synchronized core reset is asserted or its release qualification is incomplete; exits to STARTUP on the first CORE_CLK edge after qualified release |
| ARCH-STATE-002 | STARTUP | `3'b001` | Initializes and evaluates readiness; exits to NORMAL when mandatory initialization completes, to FAULTED on a mandatory failure, or to DEGRADED when only an enabled optional function fails |
| ARCH-STATE-003 | NORMAL | `3'b011` | Active when initialization is complete and no degraded/fault/test condition has priority |
| ARCH-STATE-004 | DEGRADED | `3'b100` | Active for at least one enabled optional-function fault; exits only after all causes clear and `DEGRADED_ACK` is accepted for the current episode |
| ARCH-STATE-005 | FAULTED | `3'b101` | Active after a mandatory or nonrecoverable fault and remains latched until system or external reset |
| ARCH-STATE-006 | TEST_DEBUG | `3'b111` | Active only when initialization is complete, qualified test-active is true, and no reset, fault, startup, or degraded condition has priority |
| ARCH-STATE-007 | Reserved | `3'b010`, `3'b110` | Never generated; every consumer treats either value as FAULTED for output gating and asserts illegal-state evidence |

Primary-state priority is RESET_ACTIVE, FAULTED, STARTUP, DEGRADED, TEST_DEBUG, NORMAL. `HOST_READY`, `INIT_COMPLETE`, `INIT_FAILED`, `OBSERVATIONAL_MODE`, and `EFFECTIVE_OPERATIONAL_ENABLE` are orthogonal registered qualifiers. RTL-002 transports every qualifier independently in `dfc_rtl002_status_t`; RTL-001 maps each qualifier to a distinct host-visible Register-Map-owned field. Effective operational enable is exactly:

`OPERATIONAL_ENABLE & INIT_COMPLETE & !INIT_FAILED & ((STATE == NORMAL) | (STATE == DEGRADED)) & !OBSERVATIONAL_MODE & !TEST_DEBUG`.

### 4.2 Startup and Readiness

| Contract ID | Startup contract |
|---|---|
| ARCH-START-001 | External/platform reset asserts `core_rst_n` asynchronously. Release is synchronized after four consecutive valid CORE_CLK rising edges. |
| ARCH-START-002 | On the first released CORE_CLK edge RTL-002 enters STARTUP; initialization qualification begins on the following edge. |
| ARCH-START-003 | RTL-001 and the RTL-024 host bridge assert host-ready only after their reset state, status collection, command mailbox, response mailbox, and DRI endpoint are empty and coherent. |
| ARCH-START-004 | A mandatory module is ready when its `ready` output is high. Startup completes when all mandatory-ready bits are high or the SRS timeout expires. |
| ARCH-START-005 | SPI commands received before host-ready are completely framed and answered BUSY with no DRI request or target side effect. |
| ARCH-START-006 | No startup step uses executable software, host-supplied data, or staggered per-module reset release. |

### 4.3 Clock and Reset Domains

| Contract ID | Domain/reset | Source and scope | Release and behavior |
|---|---|---|---|
| ARCH-CLK-001 | CORE_CLK | `core_clk_i`, nominal 50 MHz; RTL-001 through RTL-024 core logic | Free-running; no RTL-generated functional clock; clock enables are synchronous |
| ARCH-CLK-002 | SPI_SCLK | `spi_sclk_i`; SPI shift/framing/CRC logic only | May stop; Mode 0; request/response ownership crosses by mailbox |
| ARCH-CLK-003 | TEST_CLK | `test_clock_i`; bounded command shift/capture wrapper only | Ignored while test authorization is inactive |
| ARCH-CLK-004 | Clock-fault indication | `clock_fault_i` from the applicable platform wrapper | Asynchronous active-high level; wrapper asserts for invalid or lost CORE_CLK and holds through at least four valid CORE_CLK edges after recovery so RTL-024 can synchronize and retain evidence |
| ARCH-RST-001 | `core_rst_n` | Derived inside RTL-024 from internal wrapper input `por_n_i`; all core-domain state | Asynchronous assertion, synchronized release after four valid edges |
| ARCH-RST-002 | `spi_rst_n` | Derived from `por_n_i`; SPI-domain state | Asynchronous assertion; release only while CS_N is high and SCLK is low; one-microsecond quiet qualification precedes framing |
| ARCH-RST-003 | `test_rst_n` | Derived from `por_n_i` and deauthorization; test-domain state | Asynchronous assertion; synchronized release in TEST_CLK after authorization; deauthorization returns TEST_DATA high impedance without waiting for TEST_CLK |
| ARCH-RST-004 | Module reset | Synchronous one-hot request from RTL-002 to the selected eligible module | Asserted for at least four CORE_CLK cycles; clears state per Appendix F; requires two consecutive ready cycles before completion |
| ARCH-RST-005 | System reset | Protected command | Resets RTL-002 through RTL-024 and clears RTL-001 configuration one CORE_CLK after reset completion is recorded |
| ARCH-RST-006 | Safety-domain reset | Protected command | Resets RTL-012 through RTL-016 state and forces all safety outputs inactive; it does not reset unrelated modules |

## 5. Logical Wrapper and Internal Connectivity

### 5.1 External Logical Pad Population

The exact logical population is owned by SRS `DFC-INTF-0001` through `DFC-INTF-0004`. The table below is a generated, nonnormative connection view showing how that population is realized by the Architecture-owned RTL-024 external ports in Appendix A. `por_n_i` and `clock_fault_i` are internal platform-wrapper inputs and consume no external configurable pad position.

| Contract ID | Interface | Positions | Logical direction and reset state |
|---|---|---:|---|
| ARCH-PAD-001 | CORE_CLK | 1 | Input |
| ARCH-PAD-002 | SPI | 4 | SCLK, CS_N, MOSI inputs; MISO output high impedance while CS_N is high and before response phase |
| ARCH-PAD-003 | Host interrupt | 1 | Active-low output, high in reset |
| ARCH-PAD-004 | GPIO | 8 | Bidirectional; output enables low in reset |
| ARCH-PAD-005 | ARINC 429 | 5 | Receive and two adapter-error inputs; two mutually exclusive TX-control outputs at `00` in reset |
| ARCH-PAD-006 | Classical CAN | 3 | RX and transceiver-error inputs; TX output recessive in reset |
| ARCH-PAD-007 | UART | 2 | RX input; TX output high in reset |
| ARCH-PAD-008 | Rotor/engine/pulse | 4 | Inputs |
| ARCH-PAD-009 | Health/discrete | 8 | Inputs |
| ARCH-PAD-010 | Logical safety outputs | 4 | Outputs at the reset-defined inactive level |
| ARCH-PAD-011 | User I/O | 4 | Bidirectional-capable; outputs inactive and output enables low for Revision A |
| ARCH-PAD-012 | Functional total | 44 | Exact total |
| ARCH-PAD-013 | TEST_ENABLE, TEST_CLOCK, TEST_DATA | 3 | Fixed test positions; TEST_DATA high impedance unless authorized output phase |

### 5.2 RTL-024 Internal Connection Classes

| Contract ID | Connection class | Producer | Consumer(s) | Rule |
|---|---|---|---|---|
| ARCH-CONN-001 | Core clock/reset | RTL-024 conditioners | RTL-001 through RTL-023 | One clock tree and qualified reset; no child-to-child clock or reset generation |
| ARCH-CONN-002 | DRI | RTL-024 host executor / RTL-001 | RTL-001 / RTL-024 host executor | One request and one response channel defined by Section 7 |
| ARCH-CONN-003 | Control/status | RTL-001 / each module | RTL-002 through RTL-024 / RTL-001 | Registered packed structures in Appendix B |
| ARCH-CONN-004 | Operating controls | RTL-002 | All applicable modules | Registered operating state, observation state, effective enable, optional enables, and module resets |
| ARCH-CONN-005 | Interrupt vector | Implemented producers in Appendix C | RTL-003 | Fixed 32-position vector; reserved positions tied low |
| ARCH-CONN-006 | Event array | RTL-001 through RTL-024 | RTL-005 | Twenty-four independent valid/ready/record channels |
| ARCH-CONN-007 | Fault vector | Implemented producers in Appendix C | RTL-013 | Fixed 32-position vector; bits 17 through 31 tied low |
| ARCH-CONN-008 | Safety request lanes | RTL-012 through RTL-015 | RTL-016 | Four distinct `dfc_safety_response_req_t` lanes; no merging before authorization |
| ARCH-CONN-009 | Canonical messages | Sources/destinations in Section 11 | RTL-021 and endpoints | Five source and five destination valid/ready channels |
| ARCH-CONN-010 | Shared buffer | RTL-017 through RTL-022 and RTL-024 SPI client | RTL-024 service | Seven typed request/response channels defined by Section 12 |
| ARCH-CONN-011 | Qualified external signals | RTL-024 adapters | RTL-006 through RTL-011, RTL-017, RTL-019, RTL-020, RTL-022 | Only synchronized or protocol-recovered signals leave RTL-024 |
| ARCH-CONN-012 | External outputs | RTL-006, RTL-016, RTL-018 through RTL-020, RTL-022 | RTL-024 pad-safe gates | RTL-024 applies reset, disable, observation, test, and invalid-state safe gating |

### 5.3 Interface Ownership Records

The following records complete the ownership fields required by `RCA-DFC-PBIO-002`, Section 15. Individual producer, consumer, signal, width, direction, clock/reset, handshake, idle, and CDC/RDC details are in Appendix A.

| Interface class | Logical owner | Physical owner | Protocol owner | Error owner | Connection owner | Verification responsibility |
|---|---|---|---|---|---|---|
| Core clock and reset | RTL-024 | Platform/technology wrapper | RTL-024 reset conditioners | RTL-024 for qualification evidence; platform for source validity | RTL-024 | Integration and RDC scopes |
| DRI | RTL-001 | N/A | RTL-024 master and RTL-001 endpoint | RTL-001 for endpoint errors; RTL-024 for timeout/transport mapping | RTL-024 | Host-interface and module-integration scopes |
| Control/status structures | Owning functional module; RTL-001 owns register storage | N/A | RTL-001 registered distribution/collection | Functional module for local error; RTL-001 for access error | RTL-024 | Register, module, and integration scopes |
| Interrupts | RTL-003 | N/A internally; wrapper/pad externally | RTL-003 | Producer for source; RTL-003 for aggregation | RTL-024 | Interrupt and integration scopes |
| Timestamp | RTL-004 | N/A | RTL-004 | RTL-004 | RTL-024 | Timestamp and integration scopes |
| Events | RTL-005 | RTL-005 register arrays | Producer for pending record; RTL-005 for arbitration/store | Producer for source loss; RTL-005 for store loss | RTL-024 | Event and integration scopes |
| Faults | RTL-013 | N/A | RTL-013 | Producer for source; RTL-013 for classification/retention | RTL-024 | Fault, safety, and integration scopes |
| Safety requests/outputs | RTL-012 through RTL-016 as allocated | Wrapper/pad for external logical output | RTL-016 authorization/gating | Producer for request; RTL-016 for output/configuration error | RTL-024 | Safety and integration scopes |
| Canonical messages | Producing/consuming endpoint and RTL-021 | RTL-024 shared storage for routed buffers | RTL-021 | Endpoint for conversion; RTL-021 for routing/drop | RTL-024 | Databus, routing, and integration scopes |
| Shared buffer | RTL-024 service; client owns queue semantics | Technology memory wrapper | RTL-024 arbiter/service | Client for queue loss; RTL-024 for service errors | RTL-024 | Buffer, module, and integration scopes |
| External functional signals | Allocated functional module and RTL-024 adapter | Platform wrapper and external board | Allocated protocol module | Functional module for digital evidence; external owner for electrical fault | RTL-024 | Interface, CDC, and integration scopes |
| Production test | RTL-024 | Platform wrapper and external fixture | RTL-024 test controller | RTL-024 for authorization/command error; fixture owner externally | RTL-024 | Test, CDC/RDC, and integration scopes |

## 6. SPI Host-Access Architecture

### 6.1 Frame Encoding

The external numeric frame is owned only by SRS requirements `DFC-INTF-0012` through `DFC-INTF-0036`. The table below binds those requirements to internal RTL-024 subblocks without creating a second protocol definition.

| Contract ID | SRS-owned input | Internal architecture binding |
|---|---|---|
| ARCH-SPI-001 | `DFC-INTF-0012` through `DFC-INTF-0016` | The SPI shift engine implements the specified mode, bit/byte order, SCLK range, MISO phase, quiet interval, and CS_N setup qualification. |
| ARCH-SPI-002 | `DFC-INTF-0017` | The opcode decoder produces an internal READ, WRITE, or invalid-opcode result and never passes an undefined opcode to CORE_CLK. |
| ARCH-SPI-003 | `DFC-INTF-0018` and `DFC-INTF-0019` | The command collector indexes fixed opcode, address, count, data, and CRC fields and rejects reserved count bits before mailbox ownership changes. |
| ARCH-SPI-004 | `DFC-INTF-0020`, `DFC-INTF-0021`, and `DFC-INTF-0026` | A byte counter derives the expected frame end from opcode and count and presents each word address/data to the ordered executor. |
| ARCH-SPI-005 | `DFC-INTF-0024` through `DFC-INTF-0026` | The response builder constructs one complete stable response payload before the response mailbox ownership toggle. |
| ARCH-SPI-006 | `DFC-INTF-0022` and `DFC-INTF-0023` | Separate command and response CRC state machines use the SRS-owned parameters and coverage boundaries; CRC state clears at every new frame. |
| ARCH-SPI-007 | `DFC-INTF-0027` | A pure combinational mapper converts local frame results and DRI completion codes to the SRS-owned SPI status encoding; reserved output values are unreachable. |
| ARCH-SPI-008 | `DFC-INTF-0025` and `DFC-INTF-0028` | The executor increments completed count only with an OK DRI response and appends read data only for that completed read. |
| ARCH-SPI-009 | `DFC-INTF-0021`, `DFC-INTF-0033`, and `DFC-INTF-0034` | The executor advances addresses and word index only after completion, stops on first failure, and does not synthesize atomicity outside an explicit Register Map staging/commit object. |

### 6.2 Acceptance, Commit, Abort, and Timeout

| Contract ID | Transaction contract |
|---|---|
| ARCH-SPI-010 | A command becomes accepted only when its final CRC bit is sampled while CS_N remains low and every preceding framing check is valid. |
| ARCH-SPI-011 | CS_N deassertion before acceptance discards all transaction state, produces no DRI request, clears transaction-scoped protected authorization, increments the saturating abort counter, sets sticky pre-acceptance-abort evidence, and does not replace last-accepted-command result fields. |
| ARCH-SPI-012 | CS_N deassertion after acceptance may truncate response shifting. It does not roll back a completed word, does not alter terminal command result, and sets sticky response-truncation evidence and the abort counter. |
| ARCH-SPI-013 | Multiword commands are ordered and non-atomic. Execution stops at the first failing word; earlier words remain committed; later words do not execute. Only explicit staging/commit registers provide atomic activation. |
| ARCH-SPI-014 | The request mailbox transfers one validated complete command from SPI_SCLK to CORE_CLK by stable payload plus synchronized ownership toggle and acknowledgement. The response mailbox uses the reverse mechanism. Each mailbox permits one outstanding object. |
| ARCH-SPI-015 | A command rejected for frame, CRC, opcode, length, count, or alignment does not enter the request mailbox. Address and access errors are returned by ordered DRI execution. |
| ARCH-SPI-016 | The executor waits at most eight CORE_CLK cycles from each DRI word acceptance through its response. On expiry it records timeout, terminates the command, and returns `0x09`. RTL-001 shall not commit a timed-out word or produce a later response for it. |
| ARCH-SPI-017 | No more than two wait-fill bytes precede the marker. MISO output enable is low while CS_N is high, before the response phase, and immediately after reset or deauthorization. |
| ARCH-SPI-018 | After `spi_rst_n` release, an RTL-024 CORE_CLK counter qualifies one microsecond of continuously high CS_N and low SCLK. A falling CS_N before qualification is ignored until it returns high; the first accepted frame also requires 50 ns from CS_N falling to the first SCLK rising edge. |
| ARCH-SPI-019 | RTL-024 owns an 11-bit transaction-sequence allocator. Functional reset sets the allocator to zero. Acceptance allocates `(allocator + 1) mod 2048`, writes that value back to the allocator exactly once, and binds it to that accepted command. A pre-acceptance abort allocates no value. |
| ARCH-SPI-020 | RTL-024 owns one working-command record and one terminal host-reconciliation record. Acceptance initializes the working record with allocated sequence, opcode, starting byte address, zero completed-word count, and no endpoint result. Each OK DRI completion increments only the working completed-word count. |
| ARCH-SPI-021 | When an accepted command reaches terminal success or failure, RTL-024 atomically replaces the entire host-reconciliation record with that command's sequence, opcode, starting address, completed-word count, definitive SPI status, and final DRI endpoint result, then sets record-valid. Response truncation does not cancel or modify the terminal replacement. Reset clears record-valid and record contents; no diagnostic clear or read changes the record. |
| ARCH-SPI-022 | Before executing the first DRI word of a READ whose requested address range intersects any host-reconciliation field, RTL-024 captures the complete preceding terminal record into a response-local snapshot. Every reconciliation word returned by that command comes from the snapshot. The read command may replace the terminal record only after every requested reconciliation word has been captured for the response. |
| ARCH-SPI-023 | Host sticky evidence bits independently retain invalid opcode, invalid length, unaligned address, invalid address, access error, protected-write failure, CRC error, internal timeout, endpoint error, pre-acceptance abort, and post-acceptance response truncation. Disappearance of the condition or completion of a later successful command does not clear evidence. |
| ARCH-SPI-024 | Saturating host counters increment as follows: CRC count on each CRC rejection; abort count on each pre-acceptance abort or post-acceptance response truncation; timeout count on each internal timeout; access-error count on each invalid opcode, invalid length, unaligned address, invalid address, access error, protected-write failure, or endpoint error; completed-command count on each terminal accepted command whose definitive SPI status is success. One occurrence increments each applicable aggregate counter at most once. |

## 7. Dragon Register Interface and Register Distribution

### 7.1 DRI Protocol

DRI is a CORE_CLK-domain, single-master, ordered, non-pipelined, one-outstanding 32-bit request/response protocol, per `ARCH-DRI-010`.

| Contract ID | Signal | Width | Contract |
|---|---|---:|---|
| ARCH-DRI-001 | `dri_req_valid`, `dri_req_ready` | 1 each | Request transfers on a rising edge with both high; VALID and all request fields remain stable while stalled |
| ARCH-DRI-002 | `dri_req_write` | 1 | One for write, zero for read |
| ARCH-DRI-003 | `dri_req_addr` | 32 | Four-byte-aligned byte address |
| ARCH-DRI-004 | `dri_req_wdata` | 32 | Full write word |
| ARCH-DRI-005 | `dri_req_wstrb` | 4 | Writes require `4'b1111`; any other value is ACCESS_ERROR |
| ARCH-DRI-006 | `dri_rsp_valid`, `dri_rsp_ready` | 1 each | Exactly one response per accepted request; response fields remain stable while stalled |
| ARCH-DRI-007 | `dri_rsp_rdata` | 32 | Read data; zero for writes unless the Register Map defines returned result data |
| ARCH-DRI-008 | `dri_rsp_code` | 3 | `000` OK, `001` DECODE_ERROR, `010` ACCESS_ERROR, `011` PROTECTED_ERROR, `100` ENDPOINT_ERROR, `101` TIMEOUT, `110` BUSY, `111` reserved |
| ARCH-DRI-009 | Response deadline | — | RTL-001 returns a response within eight cycles of acceptance and performs a write side effect only in the same cycle that it commits an OK response |
| ARCH-DRI-010 | Single accepted-request object | — | RTL-001 decodes and tracks at most one accepted, unresolved request at a time; a second request shall not be accepted until the first reaches terminal disposition (OK, an error code, or internal timeout) |
| ARCH-DRI-011 | No duplicate or late response | — | Once a request reaches terminal disposition per `ARCH-DRI-010` — including an internal timeout under `ARCH-SPI-016` — RTL-001 shall not produce a second response or a later untracked write for that request |

### 7.2 RTL-001 Processing

| Contract ID | Register-bank contract |
|---|---|
| ARCH-REG-001 | RTL-001 validates alignment, mapped address, access class, reserved bits, legal value, protection state, staging state, and endpoint readiness in that order; the first failure determines response and first-error evidence. |
| ARCH-REG-002 | A valid write to RTL-001-owned storage commits atomically with its OK response. A functional command pulse is one CORE_CLK cycle and is issued only with an OK response. |
| ARCH-REG-003 | Functional modules never receive partially validated configuration. RTL-001 outputs registered control structures and receives registered coherent status structures. |
| ARCH-REG-004 | Protected authorization is cleared by reset, successful protected use, bad key, malformed protected access, CRC failure, pre-acceptance abort, timeout, or unauthorized protected access. Response truncation after acceptance does not restore consumed authorization. |
| ARCH-REG-005 | For host and routed sensor updates becoming eligible in the same cycle, the host commit wins; the routed update remains pending if its source handshake can stall, otherwise it is rejected and counted as lost. |
| ARCH-REG-006 | Proxy reads are nondestructive unless an explicit POP command is accepted. Snapshot, pop, clear, push, service, validate, commit, and reset are explicit commands. |

## 8. Interrupt, Timestamp, and Event Architecture

### 8.1 Interrupt Equations

For each source bit `i`, RTL-003 implements:

`RAW[i] = irq_source_i[i] | injected_i[i]`

`LATCH[i]_next = RAW[i] | (LATCH[i] & !CLEAR[i])`

`PENDING[i] = ENABLE[i] & LATCH[i]`

`ACKED[i]_next = (ACKED[i] | ACK[i]) & !(CLEAR[i] & !RAW[i])`

New RAW dominates simultaneous CLEAR. Reserved bits 24 through 31 have RAW, LATCH, PENDING, and ACKED tied zero; writes selecting them are rejected. `VECTOR_VALID = |PENDING`; `VECTOR_SOURCE` is the lowest numbered set PENDING bit. `host_irq_n = !(GLOBAL_IRQ_ENABLE & VECTOR_VALID)`. The complete allocation is Appendix C.

### 8.2 Timestamp

| Contract ID | Timestamp contract |
|---|---|
| ARCH-TIME-001 | RTL-004 resets raw timestamp and a six-bit phase counter to zero. The phase counter advances every valid CORE_CLK edge after release and produces a tick when its prior value is 49; the same edge sets phase to zero and increments raw timestamp. |
| ARCH-TIME-002 | The first tick is therefore the fiftieth valid rising edge after synchronized release and subsequent ticks occur every fifty edges. Raw time never stops and the legacy enable control is constant one. |
| ARCH-TIME-003 | SNAPSHOT captures raw timestamp, correlated timestamp, correlation-valid, and update sequence from one pre-increment hardware instant. If SNAPSHOT and tick coincide, the snapshot contains the value before that tick. |
| ARCH-TIME-004 | COMMIT validates and atomically copies the staged signed 64-bit two's-complement offset, increments the 16-bit wrapping update sequence, and sets correlation-valid. If SNAPSHOT and COMMIT coincide, COMMIT occurs first for snapshot correlation. |
| ARCH-TIME-005 | Correlated time equals unsigned raw time plus the signed offset modulo `2^64` when enabled and valid, otherwise raw time. Signed overflow or underflow sets sticky correlation-error evidence; arithmetic never changes raw time. |
| ARCH-TIME-006 | Priority is reset, module reset, COMMIT, SNAPSHOT, tick, clear evidence. A new arithmetic error dominates clear. |

### 8.3 Event Record, Arbitration, and Store

`dfc_event_record_t` is defined in Appendix B. Timestamp is always raw time. Event flags are: bit 0 assertion, bit 1 recovery, bit 2 sticky, bit 3 injected, bit 4 overflow report, bit 5 configuration rejection, bit 6 loss/coalesced, bit 7 reserved zero.

| Contract ID | Event contract |
|---|---|
| ARCH-EVT-001 | Each of 24 producers owns one pending record slot. An arriving enabled record enters an empty slot; an arrival to an occupied slot increments that source's saturating loss counter, sets its overflow evidence, and schedules event `0x007E`. |
| ARCH-EVT-002 | RTL-005 first services pending event-store overflow `0x007F`, then source overflow `0x007E`, then ordinary producers by rotating round-robin starting after the last accepted ordinary source. At most one record is stored per CORE_CLK. |
| ARCH-EVT-003 | Multiple losses of the same overflow class are coalesced while its report is pending; counts include every loss. `0x007F` has priority over `0x007E`. |
| ARCH-EVT-004 | The event store is four `64 × 32` register arrays forming 64 atomic 128-bit records. This is the sole exception to the centralized shared-buffer service. |
| ARCH-EVT-005 | A push to a nonfull store appends at tail. POP removes the oldest. A push-only while full overwrites the oldest, advances head and tail together, keeps level 64, sets overflow, increments the store-overflow counter, and schedules `0x007F`. |
| ARCH-EVT-006 | Simultaneous push and POP on a nonempty store removes the old head and appends the new record with unchanged level. POP on empty is rejected and sets pop-error. CLEAR_ALL has priority over POP and ordinary push. |
| ARCH-EVT-007 | An internally generated `0x007E` or `0x007F` record never increments a source/store overflow counter and never generates another overflow record solely because the diagnostic record itself encounters full storage. Storing one while full uses coincident internal pop plus push. |
| ARCH-EVT-008 | CAPTURE_OLDEST atomically snapshots the oldest complete record without removal. If CAPTURE, POP, and push coincide: CLEAR_ALL first; otherwise snapshot old head, then POP, then push. |

## 9. Monitoring and Health Algorithms

| Contract ID | Module(s) | Complete algorithm |
|---|---|---|
| ARCH-MON-001 | RTL-006 | Each GPIO input passes a two-flop synchronizer and an 8-bit millisecond stable-time counter. Qualification value zero passes the second-stage value without delay; nonzero commits a change after that many consecutive 1 ms samples. Qualification-in-progress is high exactly while the synchronized value differs from the last qualified value. Commanded output is the OR of the configured GPIO output and the authorized RTL-023 route request. Effective output data equals commanded output while output operation is permitted and otherwise zero. Effective OE is direction bit AND module enable AND effective operational enable AND not reset, test, or observation. RTL-006 independently reports raw, synchronized, qualified, commanded-output, effective-output, direction, qualification-in-progress, and retained event state. Rising, falling, either-edge, active-high, and active-low subconditions are independently masked; level requests remain active while the qualified level matches. |
| ARCH-MON-002 | RTL-007/008/009 | A selected edge is accepted only after `MIN_EDGE_CYCLES` since the preceding accepted edge. Period mode is used after two consecutive periods at least 1,000 cycles; count mode after two consecutive periods below 1,000; return to period mode after two above 1,250. Count-mode gate is 100,000 cycles. |
| ARCH-MON-003 | RTL-007/008 | `RPM = round_nearest((60 × 50,000,000) / (period_ticks × PPR))` in period mode and `round_nearest((edge_count × 50,000,000 × 60) / (100,000 × PPR))` in count mode. Ties round upward. A 64-bit-or-wider unsigned intermediate is used and the 16-bit result saturates. |
| ARCH-MON-004 | RTL-009 | `FREQ_Q17_15 = round_nearest((50,000,000 << 15) / period_ticks)` or `round_nearest((edge_count × 50,000,000 << 15) / 100,000)`. Ties round upward; a 64-bit-or-wider intermediate is used and the 32-bit result saturates. |
| ARCH-MON-005 | RTL-007/008/009 | No-edge elapsed time is a saturating microsecond counter. Reaching configured nonzero timeout clears valid and sets timeout. Low enters at value `< LOW`; exits at `>= LOW + HYST`. High enters at value `> HIGH`; exits at `<= HIGH - HYST`; unsigned arithmetic saturates at its numeric limits. A new estimate is compared in its commit cycle. |
| ARCH-MON-006 | RTL-010 | Value, low threshold, high threshold, and hysteresis are signed 32-bit two's-complement. Valid low enters at `value < low`; exits at `value >= low + hyst`. Valid high enters at `value > high`; exits at `value <= high - hyst`; signed bound arithmetic saturates. |
| ARCH-MON-007 | RTL-010 | Host or routed commit atomically replaces value, valid, 7-bit source, 24-bit sequence, and age=0. Host has same-cycle priority. Age increments each 1 ms tick and saturates. Nonzero MAX_AGE asserts stale when `age > MAX_AGE`; zero disables stale. Low, high, stale, and invalid are independent event/interrupt mask bits `[0]` through `[3]`. |
| ARCH-MON-008 | RTL-011 | Each health input uses a two-flop synchronizer, polarity transform, and stable-time qualification. For qualification value `Q=0`, synchronized state passes without delay and qualification-in-progress is zero. For `Q>0`, qualification-in-progress is high while synchronized state differs from qualified state; a consecutive-stability counter commits the new qualified state after `Q` consecutive 1 ms samples. A separate attempt counter starts on entry to qualification-in-progress, does not restart when the synchronized candidate toggles, and sets sticky qualification-failure if no qualified-state commit occurs within `min(255, 4 x Q)` consecutive 1 ms samples. Commit or return to the prior qualified state ends the attempt; neither clears prior failure evidence. `active = qualified XOR !ACTIVE_HIGH`. Sticky asserted captures active. Sticky recovered captures each active-to-inactive transition. Aggregate health fault is the current OR of active channels with fault-enable. RTL-011 independently reports raw, synchronized, qualified, qualification-in-progress, active, sticky asserted, sticky recovered, sticky qualification-failure, and aggregate health fault. |

## 10. Safety Architecture

### 10.1 Fault Manager

RTL-013 consumes the fixed allocation in Appendix C. For bit `i`, `ACTIVE[i]` is the current qualified source, `STICKY[i]_next = ACTIVE[i] | (STICKY[i] & !CLEAR[i])`, and clear is effective only when ACTIVE is zero. Primary source is the lowest-numbered active bit, or the lowest sticky bit when no source is active. The fixed recoverability mask is `0x00017FEF`; bits outside 0 through 16 are zero and rejected in configuration masks. Nonrecoverable active or sticky evidence requests FAULTED; recoverable active evidence requests DEGRADED. Fault class, event, interrupt, and safety-response outputs preserve the source bit.

### 10.2 Safety-Response Mapping

`mask_bit = 8 × lane + source_id`.

| Contract ID | Lane | Producer | Legal source IDs | Authorization bits |
|---|---:|---|---|---|
| ARCH-SAFE-001 | 0 | RTL-012 watchdog | 0 | 0 |
| ARCH-SAFE-002 | 1 | RTL-013 fault manager | 0 | 8 |
| ARCH-SAFE-003 | 2 | RTL-014 interlock | 0 through 7 | 16 through 23 |
| ARCH-SAFE-004 | 3 | RTL-015 lost-link | 0 through 7 | 24 through 31 |

Bits 1 through 7 and 9 through 15 are reserved. A producer shall never assert a reserved source ID; a channel authorization write setting a reserved bit is rejected.

### 10.3 Watchdog, Interlock, and Lost Link

| Contract ID | Module | Contract |
|---|---|---|
| ARCH-SAFE-005 | RTL-012 | Accepted service key is `0xA5C35A3C`. Service before MIN_WINDOW is EARLY; after MAX_WINDOW is LATE; any other key is INVALID. An enabled counter begins at zero, increments in microseconds, times out when elapsed first equals MAX_WINDOW without valid service, and restarts at zero only on valid in-window service. Recovery requires one valid in-window service after the source condition clears. |
| ARCH-SAFE-006 | RTL-014 | Eight expressions each use four terms, per-term inversion, one of: AND, OR, 3-of-4, or `(t0 AND t1) OR (t2 AND t3)`. COMMIT_ALL validates all terms, operators, guards, response masks, and reserved bits in entry order then field order; the first error rejects the entire bank. Violation is `enabled & !expression`. Guard permission changes inactive in the same edge that violation qualifies. |
| ARCH-SAFE-007 | RTL-015 | Eight monitors select from activity IDs: 0 host accepted command, 1 ARINC RX word, 2 CAN RX frame, 3 UART RX byte, 4 GPIO any qualified transition, 5 health any qualified transition, 6 user diagnostic input transition, 7 external watchdog-service pulse. IDs 8 through 15 are reserved. Activity must persist through QUALIFY_US when nonzero. Loss asserts when the absence counter first equals TIMEOUT_US; recovery requires continuous qualified activity for RECOVERY_US. |
| ARCH-SAFE-008 | RTL-015 | `LLINK_ACTIVITY_INJECT[0]` injects one activity pulse into the selected monitor and `[1]` injects loss evidence for that monitor. Either command is accepted only in qualified test-active state, is tagged injected, cannot suppress natural activity/loss, and uses a separate OR input to the evidence path. |

### 10.4 Logical Safety Outputs

For channel `c`, `REQUESTED[c]` is the OR of every currently active lane request whose response mask contains `c` and whose fixed authorization bit is set in that channel's mask. `LATCHED_REQUEST[c]` is zero when latch policy is disabled. When latch policy is enabled, an active request sets the retained latch; it clears only on channel disable, safety-domain reset, system reset, or external reset after every contributing request is inactive. Re-enabling a channel begins with its latch clear.

`COMMANDED[c] = REQUESTED[c] | LATCHED_REQUEST[c]`.

`CHANNEL_DISABLED[c] = !channel_enable[c]`. `CONTROLLER_DISABLED = !safety_control__enable`. `GLOBAL_INHIBIT = safety_control__global_inhibit`. `OPERATIONAL_INHIBIT = !effective_operational_enable`. `OBSERVATIONAL_INHIBIT = observational_mode`. `TEST_INHIBIT` is the OR of physical production-test authorization, qualified test-active, and TEST_DEBUG. `INTERLOCK_INHIBIT[c]` is high when any interlock required by channel `c` is unsatisfied. `FAULT_INHIBIT[c]` is asserted whenever the RTL-013 channel inhibit is active. `RESET_HELD[c]` is high during external, system, safety-domain, or channel-local reset and during reset-release qualification.

`PERMIT[c] = !CHANNEL_DISABLED[c] & !CONTROLLER_DISABLED & !GLOBAL_INHIBIT & !OPERATIONAL_INHIBIT & !OBSERVATIONAL_INHIBIT & !TEST_INHIBIT & !INTERLOCK_INHIBIT[c] & !FAULT_INHIBIT[c] & !RESET_HELD[c]`.

`EFFECTIVE[c] = COMMANDED[c] & PERMIT[c]`.

`safety_out[c] = ACTIVE_HIGH[c] ? EFFECTIVE[c] : !EFFECTIVE[c]` after reset release; reset and unconfigured startup use the Register-Map-owned reset polarity and inactive level. RTL-016 independently reports REQUESTED, LATCHED_REQUEST, COMMANDED, EFFECTIVE, CHANNEL_DISABLED, CONTROLLER_DISABLED, GLOBAL_INHIBIT, OPERATIONAL_INHIBIT, OBSERVATIONAL_INHIBIT, TEST_INHIBIT, INTERLOCK_INHIBIT, FAULT_INHIBIT, and RESET_HELD for the selected channel. Aggregate inhibited state is the OR of the nine inhibit causes and never substitutes for a cause. No test indication is permitted on a safety-output pad.

## 11. Databus Message and Routing Architecture

### 11.1 Canonical Record and Endpoints

The 192-bit canonical record layout is Appendix B. Source and destination identifiers are:

| Contract ID | ID | Source | Destination |
|---|---:|---|---|
| ARCH-MSG-001 | `0x00` | ARINC RX / RTL-017 | ARINC TX / RTL-018 |
| ARCH-MSG-002 | `0x01` | CAN RX / RTL-019 | CAN TX / RTL-019 |
| ARCH-MSG-003 | `0x02` | UART RX / RTL-020 | UART TX / RTL-020 |
| ARCH-MSG-004 | `0x03` | Host ingress / RTL-001 | Host egress / RTL-001 |
| ARCH-MSG-005 | `0x04` | ULI / RTL-022 | ULI / RTL-022 |

Message types are `0x01` ARINC_WORD, `0x02` CAN_FRAME, `0x04` UART_BYTE, `0x08` HOST_OPAQUE, and `0x10` ULI_DIAGNOSTIC; all others are reserved. Payload length is 0 through 8. Flags bits are: 0 parity/error, 1 framing/protocol error, 2 remote frame, 3 extended identifier, 4 injected, 5 truncated/lost, 6 timestamp valid, 7 reserved zero. The four-bit sequence field wraps modulo 16 per source.

Metadata is type-specific: ARINC uses bits 31:0 for the received/transmitted word and payload length zero; CAN uses bits 28:0 identifier, bit 29 IDE, bit 30 RTR, bit 31 reserved zero and payload for data; UART uses metadata bits 7:0 for the byte and bits 31:8 zero with payload length zero; HOST_OPAQUE and ULI_DIAGNOSTIC use metadata as a producer-defined tag and payload length 0 through 8. Reserved metadata bits must be zero.

### 11.2 Fixed 5 × 5 Authorization Matrix

`1` means the source/destination pair may be enabled by a valid route; `0` is rejected.

| Source \ Destination | ARINC TX | CAN TX | UART TX | Host | ULI |
|---|---:|---:|---:|---:|---:|
| ARINC RX | 0 | 1 | 1 | 1 | 0 |
| CAN RX | 1 | 0 | 1 | 1 | 0 |
| UART RX | 1 | 1 | 0 | 1 | 0 |
| Host | 1 | 1 | 1 | 0 | 1 |
| ULI | 0 | 0 | 0 | 1 | 0 |

### 11.3 Routing Algorithm

| Contract ID | Routing contract |
|---|---|
| ARCH-ROUTE-001 | Each source owns one ingress slot. Source READY is high when its slot is empty and routing is enabled. Accepted messages are range-checked before the slot becomes valid. |
| ARCH-ROUTE-002 | Sixteen active route entries contain enable, one 8-bit source ID, one five-bit destination mask, one 32-bit message-type mask, 32-bit metadata filter value/mask, and DROP_ON_FULL. |
| ARCH-ROUTE-003 | For an ingress record, every enabled matching route is evaluated in entry order. A destination copy is selected if source matches, type bit is enabled, `(metadata & filter_mask) == (filter_value & filter_mask)`, and the fixed matrix authorizes the pair. Duplicate selections of the same destination produce one copy. |
| ARCH-ROUTE-004 | Destination queues are independent four-record queues. When DROP_ON_FULL=0, a required full destination backpressures completion of that ingress record. When DROP_ON_FULL=1, that copy is dropped, its saturating count and sticky evidence update, and other copies proceed. |
| ARCH-ROUTE-005 | An ingress record is released only after every selected destination has accepted, dropped, or been found inapplicable. A blocked destination never prevents already-ready independent copies from committing. |
| ARCH-ROUTE-006 | Each destination chooses among eligible ingress records by rotating round-robin and advances its pointer after a committed copy. Filter mismatch is evidence only when an enabled route matched source/type but failed its nonzero filter. |
| ARCH-ROUTE-007 | Commit validation error codes are `00` none, `01` invalid entry, `02` invalid source, `03` zero/invalid destination mask, `04` unauthorized pair, `05` undefined type bit, `06` reserved flag/field, `07` duplicate conflict, `08` busy; `09` through `FF` reserved. |
| ARCH-ROUTE-008 | Runtime LAST_ERROR values are `00` none, `10` malformed message, `11` no matching route, `12` filter mismatch, `13` destination full/drop, `14` shared-buffer error, `15` destination rejection; all others reserved. |

### 11.4 Wire-Protocol Contracts

| Contract ID | Interface | Required state-machine behavior |
|---|---|---|
| ARCH-BUS-001 | ARINC RX | RTL-024 oversamples the conditioned input in CORE_CLK, recognizes configured 12–14.5 kb/s or 100 kb/s timing, requires at least four bit times of null between words, assembles 32 bits LSB-first as transmitted by ARINC, evaluates odd parity, and presents one atomic word/metadata transfer to RTL-017. |
| ARCH-BUS-002 | ARINC TX | RTL-018 dequeues in order, emits 32 bits LSB-first, inserts or validates odd parity as configured, holds `00` for the configured interword gap, and drives `01` low-speed or `10` high-speed active control; `11` is never generated. |
| ARCH-BUS-003 | CAN | RTL-019 implements Classical CAN base/extended data and remote frames, bit stuffing, arbitration, ACK, CRC-15, error frames, TEC/REC, error-active/passive, and bus-off. Loopback disconnects external TX; listen-only never drives dominant. Recovery requires host command or 128 occurrences of eleven recessive bits as configured. |
| ARCH-BUS-004 | UART | `BAUD_DIV = round(50,000,000/baud)` CORE_CLK cycles per bit, legal from 50 through 50,000; reset is 434 for nominal 115,200 baud. A fractional phase accumulator derives 16 evenly spaced sample phases and votes the three samples centered on each bit. Format is 8 data bits, parity 0 none/1 even/2 odd, and one or two stop bits; parity 3 is rejected. One UART byte maps to one type-`0x04` record. |

For CAN, actual quanta are `BRP = PRESCALER_MINUS_1 + 1`, `TSEG1 = TSEG1_MINUS_1 + 1`, `TSEG2 = TSEG2_MINUS_1 + 1`, and `SJW = SJW_MINUS_1 + 1`. The nominal bit rate is `50,000,000 / (BRP × (1 + TSEG1 + TSEG2))`. Legal configuration requires 8 through 25 total quanta, TSEG1 2 through 16, TSEG2 1 through 8, SJW 1 through `min(4,TSEG2)`, bit rate no greater than 1 MHz, and absolute rate error no greater than 1 percent of the requested nominal rate. Loopback/listen-only `00` is normal, `01` is internal loopback with external TX recessive, `10` is silent listen-only, and `11` is rejected. DLC is 0 through 8; standard identifiers require bits 28:11 zero; remote frames require all staged data bytes zero. Automatic bus-off recovery waits for 128 occurrences of eleven consecutive recessive bits; manual recovery begins only on `CAN_RECOVERY.REQUEST` after the same observation requirement is met.

ARINC RX and TX use odd parity. `ACCEPT_PARITY_ERROR=0` rejects a parity-failed receive word; one admits it with error flags set. TX `AUTO_PARITY=1` computes bit 32 for odd parity; when zero, the staged override-valid bit must be one. Interword gap is legal from 4 through 255 bit times. ARINC status error codes are `000` none, `001` parity, `002` framing/gap, `003` receive overrun, `004` transmit underrun, `005` adapter error, `006` disabled, `007` invalid configuration, and `008` shared-buffer error; `009` through `FFF` are reserved.

UART receive error flags are bit 0 framing, bit 1 parity, bit 2 overrun, bit 3 break, bit 4 shared-buffer error, and bits 5 through 7 reserved zero. CAN receive metadata flags are bit 0 CRC error, bit 1 stuff error, bit 2 form error, bit 3 bit error, bit 4 ACK error, bit 5 arbitration lost, bit 6 error passive, bit 7 bus off, bit 8 transceiver error, bit 9 injected, and bits 10 through 11 reserved zero.

## 12. Centralized Shared-Buffer Service

### 12.1 Physical Contract and Allocation

RTL-024 owns one logical `512 × 32-bit`, CORE_CLK-domain storage service. It is an internal subblock, not RTL-025. RTL-005 does not use it.

| Contract ID | Word addresses | Owner/use | Entry form |
|---|---|---|---|
| ARCH-BUF-001 | `0x000–0x00F` | RTL-024 SPI command | 16 words |
| ARCH-BUF-002 | `0x010–0x01F` | RTL-024 SPI response | 16 words |
| ARCH-BUF-003 | `0x020–0x03F` | RTL-017 ARINC RX | 8 × 4 words |
| ARCH-BUF-004 | `0x040–0x04F` | RTL-018 ARINC TX | 8 × 2 words |
| ARCH-BUF-005 | `0x050–0x07F` | RTL-019 CAN RX | 8 × 6 words |
| ARCH-BUF-006 | `0x080–0x0AF` | RTL-019 CAN TX | 8 × 6 words |
| ARCH-BUF-007 | `0x0B0–0x0BF` | RTL-020 UART RX | 16 × 1 word |
| ARCH-BUF-008 | `0x0C0–0x0CF` | RTL-020 UART TX | 16 × 1 word |
| ARCH-BUF-009 | `0x0D0–0x0ED` | RTL-021 routing ingress | 5 × 6 words |
| ARCH-BUF-010 | `0x0EE–0x165` | RTL-021 destination queues | 5 × 4 × 6 words |
| ARCH-BUF-011 | `0x166–0x16D` | RTL-022 input/output mailboxes | 2 × 4 words |
| ARCH-BUF-012 | `0x16E–0x1FF` | Reserved | Reads return zero; writes return RANGE_ERROR |

### 12.2 Request/Response Protocol

The seven clients are numbered 0 RTL-017, 1 RTL-018, 2 RTL-019, 3 RTL-020, 4 RTL-021, 5 RTL-022, and 6 RTL-024 SPI. Each uses `dfc_buffer_req_t` and `dfc_buffer_rsp_t` from Appendix B with independent valid/ready channels.

| Contract ID | Service contract |
|---|---|
| ARCH-BUF-013 | A client may have one outstanding request. Request fields remain stable until accepted; response remains stable until accepted. |
| ARCH-BUF-014 | The arbiter accepts at most one request per CORE_CLK using rotating round-robin beginning after the last accepted client. Every continuously eligible client is accepted within seven acceptance opportunities. |
| ARCH-BUF-015 | Legal READ and WRITE requests complete with OK within eight CORE_CLK cycles of acceptance. Codes are `00` OK, `01` RANGE_ERROR, `10` PROTOCOL_ERROR, `11` INTERNAL_ERROR. |
| ARCH-BUF-016 | The service derives the absolute address as client segment base plus client-relative word offset and rejects any offset outside the client's assigned ranges. No client supplies an unrestricted absolute address. |
| ARCH-BUF-017 | A WRITE updates one 32-bit word atomically. An entry owner shall write every word before advancing its local tail/valid state. A reader may issue entry reads only after observing owner-local valid state. |
| ARCH-BUF-018 | Queue pointers, occupancy, valid state, entry sequencing, backpressure, overflow, underflow, rejected-access, drop evidence, and resource loss counters remain in the client module. Physical memory contents are not cleared by reset and are never exposed until client valid state authorizes them. |
| ARCH-BUF-019 | Module reset invalidates only that client's queue/mailbox state, clears its local evidence and counters, and cancels its outstanding request. System reset invalidates all clients and resets arbitration. A canceled response is discarded and cannot change client state. |
| ARCH-BUFERR-001 | A non-OK buffer response sets sticky error evidence for the requesting client and increments its client-error count. RANGE_ERROR and PROTOCOL_ERROR do not increment the service internal-error count; INTERNAL_ERROR increments both the client and service internal-error counts. |
| ARCH-BUF-020 | Revision A uses no architectural ECC or parity. FPGA BRAM, ASIC SRAM, or inferred storage may implement the service only through a wrapper preserving this contract. |

### 12.3 Entry Word Layouts

All entries use little word order within their assigned segment: entry word 0 occupies the lowest address. Each 32-bit word uses the bit numbering shown; SPI byte order does not alter stored word bit numbering.

| Contract ID | Entry | Word layout |
|---|---|---|
| ARCH-BUF-021 | SPI command/response | One complete 32-bit DRI data word per storage word, in transaction word order; frame headers and CRC state remain in RTL-024 registers |
| ARCH-BUF-022 | ARINC RX, four words | W0 received word; W1 bits 0 parity-ok, 1 framing-ok, 2 high-speed, 3 adapter-error, 15:4 error code, 31:16 sequence; W2 raw timestamp low; W3 raw timestamp high |
| ARCH-BUF-023 | ARINC TX, two words | W0 transmit word; W1 bits 0 high-speed, 1 auto-parity, 2 override-valid, 3 override parity bit, 17:4 tag, 31:18 zero |
| ARCH-BUF-024 | CAN RX/TX, six words | W0 bits 28:0 identifier, 29 IDE, 30 RTR, 31 valid; W1 data bytes 0–3; W2 data bytes 4–7; W3 raw timestamp low; W4 raw timestamp high; W5 bits 3:0 DLC, 15:4 flags, 31:16 sequence |
| ARCH-BUF-025 | UART RX, one word | Bits 7:0 data, 15:8 error flags, 31:16 sequence |
| ARCH-BUF-026 | UART TX, one word | Bits 7:0 data, 31:8 zero |
| ARCH-BUF-027 | Routing ingress/destination, six words | W0 canonical bits 31:0; W1 bits 63:32; W2 bits 95:64; W3 bits 127:96; W4 bits 159:128; W5 bits 191:160 |
| ARCH-BUF-028 | RTL-022 mailboxes | One opaque diagnostic 32-bit word per entry; no operational interpretation |

## 13. User Logic and User-Configurable Signal Routing

### 13.1 RTL-022 Inert Revision A Profile

| Contract ID | ULI contract |
|---|---|
| ARCH-ULI-001 | All eight functional parameters have the sole legal value zero. Any nonzero parameter write or enable attempt is rejected and sets violation evidence. |
| ARCH-ULI-002 | `user_o` is `4'b0000`, `user_oe` is `4'b0000`, `tx_msg_valid` is zero, and operational event/interrupt/fault outputs are zero in every state. |
| ARCH-ULI-003 | Four synchronized user inputs are captured in status. Input mailbox PUSH stores one 32-bit diagnostic word into the four-word assigned segment; output mailbox contains only words written through the diagnostic host proxy and POP removes one. Neither mailbox creates an operational action. |
| ARCH-ULI-004 | RESET_REQ and module reset empty both mailbox pointer/valid sets, clear violation/reset evidence as defined, and leave all functional parameters in RTL-001 unchanged. |
| ARCH-ULI-005 | Route-source, route-destination, and message-destination inputs are observed only as diagnostics and never affect an output in Revision A. |

### 13.2 RTL-023 Exact Signal Routing

Source IDs and destination IDs are Appendix C. Sixteen entries contain 8-bit source, 8-bit destination, enable, invert, and mode: 0 level, 1 rising one-cycle pulse, 2 falling one-cycle pulse, 3 either-edge one-cycle pulse. Source values are sampled synchronously; prior source state is updated every enabled cycle.

The fixed authorization is: source IDs 1–31 may drive destinations 1–8; source IDs 1–31 may drive destinations 21–24; only source IDs 1–16 may drive destinations 13–20; no source may drive destinations 9–12 in Revision A because RTL-022 outputs are inert. Source 0 may be staged only for a disabled entry. Source 37 constant-one may drive level-mode destinations 21–24 only. Every other pair is rejected.

Destinations 1–12 are exclusive: a commit containing more than one enabled entry for one such destination is rejected. Destinations 13–24 are wired-OR. Runtime output is the OR of all authorized active entry results; for exclusive destinations the one committed entry is used. Disable, reset, invalid state, or effective-operational-enable low forces all destinations zero. `VALIDATE_COMMIT` has priority over `DISABLE_ENTRY`; if both are commanded, the complete operation is rejected BUSY with no active change. New command-result evidence dominates clear.

## 14. Production-Test Architecture

### 14.1 Authorization and Command Framing

| Contract ID | Test contract |
|---|---|
| ARCH-TEST-001 | Physical authorization is `test_enable_i` high for four consecutive CORE_CLK cycles. Deassertion asynchronously removes authorization from the TEST_DATA output-enable path and synchronously clears test-active and any command. |
| ARCH-TEST-002 | Qualified `test_active` requires physical authorization, protected `TEST_CONTROL.ENABLE`, and two synchronized TEST_CLK edges. The same qualified state feeds RTL-002 and reported test status. |
| ARCH-TEST-003 | TEST_DATA receives a 32-bit command word LSB-first on TEST_CLK rising edges: opcode bits 7:0 and argument bits 31:8. A command executes only after all 32 bits are received while authorization remains active. |
| ARCH-TEST-004 | Opcodes are `0x01` CAPTURE, `0x02` SHIFT, and `0x03` SAFE_LOOPBACK. Others are rejected. CAPTURE argument must be zero. SHIFT argument bits 8:0 are length-minus-one (`0–255` means 1–256 bits) and bits 23:9 zero. SAFE_LOOPBACK argument bits 2:0 select, bit 3 enable, and bits 23:4 zero. |
| ARCH-TEST-005 | Busy, malformed, reserved, unauthorized, or deauthorized commands terminate without a functional side effect, set rejection evidence, and leave every safety output inactive. |
| ARCH-TEST-006 | CAPTURE atomically samples the vector in Section 14.2 into a TEST_CLK shift register through the CDC-TEST-002 snapshot handshake. SHIFT outputs bit 0 first and shifts exactly the requested count. TEST_DATA is high impedance at all other times. |
### 14.2 Diagnostic Capture Vector

| Contract ID | Bits | Captured value |
|---|---:|---|
| ARCH-TEST-007 | 31:0 | Fixed identification word `0x44464341` (`DFCA`) |
| ARCH-TEST-008 | 63:32 | RTL-024 host last address |
| ARCH-TEST-009 | 95:64 | Host sticky status, result, and completed-count summary; unused bits zero |
| ARCH-TEST-010 | 127:96 | RTL-003 pending interrupt vector |
| ARCH-TEST-011 | 159:128 | RTL-013 active fault vector |
| ARCH-TEST-012 | 191:160 | RTL-013 sticky fault vector |
| ARCH-TEST-013 | 223:192 | Shared-buffer client busy/error summary, queue nonempty summary, and reserved zeros |
| ARCH-TEST-014 | 239:224 | RTL-002 operating state and readiness summary; unused bits zero |
| ARCH-TEST-015 | 247:240 | Qualified external-input summary: SPI CS, ARINC RX, CAN RX, UART RX, rotor, engine, any pulse, any health |
| ARCH-TEST-016 | 255:248 | Test status: physical authorization, active, busy, complete, rejected, safety-blocked, loopback-enabled, reserved zero |

### 14.3 Production-Test Diagnostic State

| Contract ID | Diagnostic contract |
|---|---|
| ARCH-TEST-017 | RTL-024 reports physical authorization, qualified active, busy, terminal-complete, terminal-rejected, terminal reason, unsafe-command rejection, safety blocking, deauthorization abort, loopback active, injection enabled, natural-fault observed, and injected-fault observed as independent state or sticky evidence. |
| ARCH-TEST-018 | Terminal reason values are `0x00` none, `0x01` complete, `0x02` invalid opcode, `0x03` invalid argument or reserved bit, `0x04` unauthorized, `0x05` busy, `0x06` unsafe command, `0x07` deauthorization abort, `0x08` CDC or internal timeout, and `0x09` safety blocked; `0x0A` through `0xFF` are reserved. |
| ARCH-TEST-019 | Every rejected or deauthorization-aborted command increments one saturating test-rejection-or-abort counter. Natural-fault-observed is set only by a noninjected source occurrence while test authorization is active; injected-fault-observed is set only by an accepted injection path. One cannot clear or suppress the other. |
| ARCH-TEST-020 | A terminal command or deauthorization abort atomically replaces terminal reason. It remains readable until the next terminal test result or reset. Clearing completion, rejection, abort, unsafe, or safety-block evidence does not change terminal reason. |

### 14.4 Eight Safe Loopback Selections

SAFE_LOOPBACK affects only the TEST_DATA shifted observation bit and never drives a functional pad.

| Select | Observation |
|---:|---|
| 0 | Internal constant-zero/constant-one alternating pattern |
| 1 | CORE_CLK divide-by-256 observation |
| 2 | Core-reset release qualification state |
| 3 | Synchronized SPI MOSI and CS_N sampler pair |
| 4 | XOR reduction of synchronized GPIO inputs |
| 5 | XOR of synchronized ARINC RX, CAN RX, and UART RX |
| 6 | XOR reduction of synchronized rotor, engine, pulse, and health inputs |
| 7 | XOR reduction of synchronized user inputs |

## 15. Diagnostic and Host-Recovery Architecture

### 15.1 Evidence Classes and Clear Independence

| Contract ID | Diagnostic contract |
|---|---|
| ARCH-DIAG-001 | Every module's `ready`, `fault`, busy, active, empty, full, occupancy, valid, and qualification-in-progress members are current state. Every member named error, overflow, underflow, rejected, aborted, truncated, timeout, violation, failure, recovered, event, or sticky is retained evidence unless its table row explicitly identifies current state. |
| ARCH-DIAG-002 | RTL-001 presents current module state and retained module evidence without read side effects. A read may capture a coherent snapshot but never acknowledges, pops, clears, or advances the observed resource. |
| ARCH-DIAG-003 | W1C clears only the selected retained bit. Whole-counter clear follows ARCH-GEN-007. New evidence or a counter increment dominates a simultaneous clear of the same item. |
| ARCH-DIAG-004 | Each module event-pending slot owns its 16-bit saturating `event_drop_count`. The module index identifies the lost source. RTL-005 separately owns its 32-bit event-store-overflow count and the per-source loss indication defined by ARCH-EVT-001 through ARCH-EVT-008. |
| ARCH-DIAG-005 | Queue and mailbox status reports applicable current empty, full, occupancy, and busy state. An empty POP sets underflow or rejected-access evidence; a full PUSH sets overflow or rejected-access evidence; a dropped ingress or destination copy sets drop evidence. Each affected host-visible resource owns a saturating loss counter identified in its Appendix B status structure. |
| ARCH-DIAG-006 | RTL-024 owns independent service-error evidence and a 16-bit saturating count indexed for each of the seven shared-buffer clients, plus independent shared-buffer-internal-error evidence and a 32-bit saturating internal-error count. Client modules continue to own queue/mailbox loss evidence and counts. A rejected range or protocol request increments only the requesting-client service count; a service internal error increments both that client count and the internal-error count. |
| ARCH-DIAG-007 | RTL-024 synchronizes `clock_fault_i` and retains platform-clock-fault and illegal reset-release evidence. RTL-002 independently retains controlled-reset timeout, reset rejection, and reset-recovery-failure evidence. Conditions that destroy power or prevent every retaining clock from operating are reportable only after the platform supplies retained source evidence, as allocated by PBIO; no same-clock circuit claims to detect its own permanent clock loss. |
| ARCH-DIAG-008 | Host transport diagnostics obey ARCH-SPI-023 and ARCH-SPI-024. Production-test diagnostics obey ARCH-TEST-017 through ARCH-TEST-019. No common summary bit or count replaces any independently required class. |
| ARCH-DIAG-009 | After host communication returns, software can read present operating state, every active configuration value, all retained diagnostic evidence and counters, event-store contents, queue/mailbox state, and the terminal host-reconciliation record without first modifying device state. |

### 15.2 Resource Loss-Counter Allocation

| Contract ID | Resource owner | Separately identified saturating counts |
|---|---|---|
| ARCH-DIAG-010 | RTL-005 | Event-store overwrite; each producer's pending-slot loss by producer index; empty POP rejection |
| ARCH-DIAG-011 | RTL-017 | ARINC RX overflow/drop; empty POP or rejected access; shared-buffer client error |
| ARCH-DIAG-012 | RTL-018 | ARINC TX full/rejected push; underrun; shared-buffer client error |
| ARCH-DIAG-013 | RTL-019 | CAN RX overflow/drop; CAN TX full/rejected push; protocol loss; shared-buffer client error |
| ARCH-DIAG-014 | RTL-020 | UART RX overflow/drop; UART TX underflow or rejected access; shared-buffer client error |
| ARCH-DIAG-015 | RTL-021 | Five ingress-slot losses by source; five destination-queue drops by destination; shared-buffer client error |
| ARCH-DIAG-016 | RTL-022 | Input- and output-mailbox overflow and underflow separately; shared-buffer client error |
| ARCH-DIAG-017 | RTL-024 | SPI command/response client error; each of seven shared-buffer client errors by client index; shared-buffer internal error; production-test rejection or abort |

## 16. Technology Boundaries and Generated Definitions

| Contract ID | Technology contract |
|---|---|
| ARCH-TECH-001 | The ECP5 and OpenFrame realizations use the same RTL-024 logical wrapper and RTL-001 through RTL-023 source. |
| ARCH-TECH-002 | Platform wrappers own pad cells, clock/reset resources, memory primitives, scan resources, and physical constraints; they preserve every logical direction, safe state, latency, ordering, and error contract. |
| ARCH-TECH-003 | Technology storage wrappers shall normalize read latency and read-during-write behavior to the centralized service contract and shall never expose uninitialized data as valid. |
| ARCH-TECH-004 | Generated packages shall contain Architecture-owned constants, types, ports, interrupt/event/fault allocations, endpoint IDs, buffer segments, and the Register-Map-owned register definitions. Independent copied constants are prohibited. |
| ARCH-TECH-005 | `dfc_constants_pkg.sv`, `dfc_types_pkg.sv`, `dfc_interrupt_pkg.sv`, and `dfc_events_pkg.sv` derive from this specification. `dfc_registers_pkg.sv` derives from the Register Map. `dfc_version_pkg.sv` contains build parameters and no document-tracking state. |

# Appendix A — Formal RTL Port Catalog

The following tables are the sole formal top-level port definitions for RTL-001 through RTL-024. Traceability and verification-case columns have been removed because those relationships belong to the RTM and Verification Plan.

### RTL-001 - Configuration Register Bank (74 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-001.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-001.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| dri_req_valid_i | input | logic / 1 | RTL-024.dri_req_valid_o | RTL-001.dri_req_valid_i | CORE_CLK / core_rst_n | valid/ready; held until accepted / 0 | same-domain |
| dri_req_ready_o | output | logic / 1 | RTL-001.dri_req_ready_o | RTL-024.dri_req_ready_i | CORE_CLK / core_rst_n | valid/ready acceptance / 0 | same-domain |
| dri_req_write_i | input | logic / 1 | RTL-024.dri_req_write_o | RTL-001.dri_req_write_i | CORE_CLK / core_rst_n | stable with request / 0 | same-domain |
| dri_req_addr_i | input | logic / 32 | RTL-024.dri_req_addr_o | RTL-001.dri_req_addr_i | CORE_CLK / core_rst_n | stable with request / 0 | same-domain |
| dri_req_wdata_i | input | logic / 32 | RTL-024.dri_req_wdata_o | RTL-001.dri_req_wdata_i | CORE_CLK / core_rst_n | stable with request / 0 | same-domain |
| dri_req_wstrb_i | input | logic / 4 | RTL-024.dri_req_wstrb_o | RTL-001.dri_req_wstrb_i | CORE_CLK / core_rst_n | stable with request; 1111 required / 0 | same-domain |
| dri_rsp_valid_o | output | logic / 1 | RTL-001.dri_rsp_valid_o | RTL-024.dri_rsp_valid_i | CORE_CLK / core_rst_n | one response per accepted request / 0 | same-domain |
| dri_rsp_ready_i | input | logic / 1 | RTL-024.dri_rsp_ready_o | RTL-001.dri_rsp_ready_i | CORE_CLK / core_rst_n | response acceptance / 0 | same-domain |
| dri_rsp_rdata_o | output | logic / 32 | RTL-001.dri_rsp_rdata_o | RTL-024.dri_rsp_rdata_i | CORE_CLK / core_rst_n | stable until accepted / 0 | same-domain |
| dri_rsp_code_o | output | logic / 3 | RTL-001.dri_rsp_code_o | RTL-024.dri_rsp_code_i | CORE_CLK / core_rst_n | stable until accepted; response within 8 cycles / 000 | same-domain |
| rtl002_control_o | output | dfc_rtl002_control_t / 60 | RTL-001.rtl002_control_o | RTL-002.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl002_status_i | input | dfc_rtl002_status_t / 112 | RTL-002.status_o | RTL-001.rtl002_status_i; RTL-002.module_ready_i[1]; RTL-002.module_fault_i[1] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl003_control_o | output | dfc_rtl003_control_t / 129 | RTL-001.rtl003_control_o | RTL-003.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl003_status_i | input | dfc_rtl003_status_t / 153 | RTL-003.status_o | RTL-001.rtl003_status_i; RTL-002.module_ready_i[2]; RTL-002.module_fault_i[2] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl004_control_o | output | dfc_rtl004_control_t / 73 | RTL-001.rtl004_control_o | RTL-004.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl004_status_i | input | dfc_rtl004_status_t / 169 | RTL-004.status_o | RTL-001.rtl004_status_i; RTL-002.module_ready_i[3]; RTL-002.module_fault_i[3] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl005_control_o | output | dfc_rtl005_control_t / 128 | RTL-001.rtl005_control_o | RTL-005.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl005_status_i | input | dfc_rtl005_status_t / 268 | RTL-005.status_o | RTL-001.rtl005_status_i; RTL-002.module_ready_i[4]; RTL-002.module_fault_i[4] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl006_control_o | output | dfc_rtl006_control_t / 123 | RTL-001.rtl006_control_o | RTL-006.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl006_status_i | input | dfc_rtl006_status_t / 83 | RTL-006.status_o | RTL-001.rtl006_status_i; RTL-002.module_ready_i[5]; RTL-002.module_fault_i[5] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl007_control_o | output | dfc_rtl007_control_t / 135 | RTL-001.rtl007_control_o | RTL-007.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl007_status_i | input | dfc_rtl007_status_t / 73 | RTL-007.status_o | RTL-001.rtl007_status_i; RTL-002.module_ready_i[6]; RTL-002.module_fault_i[6] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl008_control_o | output | dfc_rtl008_control_t / 136 | RTL-001.rtl008_control_o | RTL-008.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl008_status_i | input | dfc_rtl008_status_t / 73 | RTL-008.status_o | RTL-001.rtl008_status_i; RTL-002.module_ready_i[7]; RTL-002.module_fault_i[7] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl009_control_o | output | dfc_rtl009_control_t / 335 | RTL-001.rtl009_control_o | RTL-009.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl009_status_i | input | dfc_rtl009_status_t / 159 | RTL-009.status_o | RTL-001.rtl009_status_i; RTL-002.module_ready_i[8]; RTL-002.module_fault_i[8] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl010_control_o | output | dfc_rtl010_control_t / 346 | RTL-001.rtl010_control_o | RTL-010.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl010_status_i | input | dfc_rtl010_status_t / 225 | RTL-010.status_o | RTL-001.rtl010_status_i; RTL-002.module_ready_i[9]; RTL-002.module_fault_i[9] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl011_control_o | output | dfc_rtl011_control_t / 121 | RTL-001.rtl011_control_o | RTL-011.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl011_status_i | input | dfc_rtl011_status_t / 84 | RTL-011.status_o | RTL-001.rtl011_status_i; RTL-002.module_ready_i[10]; RTL-002.module_fault_i[10] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl012_control_o | output | dfc_rtl012_control_t / 111 | RTL-001.rtl012_control_o | RTL-012.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl012_status_i | input | dfc_rtl012_status_t / 58 | RTL-012.status_o | RTL-001.rtl012_status_i; RTL-002.module_ready_i[11]; RTL-002.module_fault_i[11] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl013_control_o | output | dfc_rtl013_control_t / 112 | RTL-001.rtl013_control_o | RTL-013.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl013_status_i | input | dfc_rtl013_status_t / 106 | RTL-013.status_o | RTL-001.rtl013_status_i; RTL-002.module_ready_i[12]; RTL-002.module_fault_i[12] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl014_control_o | output | dfc_rtl014_control_t / 513 | RTL-001.rtl014_control_o | RTL-014.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl014_status_i | input | dfc_rtl014_status_t / 115 | RTL-014.status_o | RTL-001.rtl014_status_i; RTL-002.module_ready_i[13]; RTL-002.module_fault_i[13] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl015_control_o | output | dfc_rtl015_control_t / 961 | RTL-001.rtl015_control_o | RTL-015.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl015_status_i | input | dfc_rtl015_status_t / 75 | RTL-015.status_o | RTL-001.rtl015_status_i; RTL-002.module_ready_i[14]; RTL-002.module_fault_i[14] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl016_control_o | output | dfc_rtl016_control_t / 226 | RTL-001.rtl016_control_o | RTL-016.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl016_status_i | input | dfc_rtl016_status_t / 52 | RTL-016.status_o | RTL-001.rtl016_status_i; RTL-002.module_ready_i[15]; RTL-002.module_fault_i[15] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl017_control_o | output | dfc_rtl017_control_t / 105 | RTL-001.rtl017_control_o | RTL-017.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl017_status_i | input | dfc_rtl017_status_t / 256 | RTL-017.status_o | RTL-001.rtl017_status_i; RTL-002.module_ready_i[16]; RTL-002.module_fault_i[16] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl018_control_o | output | dfc_rtl018_control_t / 163 | RTL-001.rtl018_control_o | RTL-018.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl018_status_i | input | dfc_rtl018_status_t / 127 | RTL-018.status_o | RTL-001.rtl018_status_i; RTL-002.module_ready_i[17]; RTL-002.module_fault_i[17] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl019_control_o | output | dfc_rtl019_control_t / 204 | RTL-001.rtl019_control_o | RTL-019.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl019_status_i | input | dfc_rtl019_status_t / 326 | RTL-019.status_o | RTL-001.rtl019_status_i; RTL-002.module_ready_i[18]; RTL-002.module_fault_i[18] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl020_control_o | output | dfc_rtl020_control_t / 216 | RTL-001.rtl020_control_o | RTL-020.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl020_status_i | input | dfc_rtl020_status_t / 217 | RTL-020.status_o | RTL-001.rtl020_status_i; RTL-002.module_ready_i[19]; RTL-002.module_fault_i[19] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl021_control_o | output | dfc_rtl021_control_t / 136 | RTL-001.rtl021_control_o | RTL-021.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl021_status_i | input | dfc_rtl021_status_t / 338 | RTL-021.status_o | RTL-001.rtl021_status_i; RTL-002.module_ready_i[20]; RTL-002.module_fault_i[20] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl022_control_o | output | dfc_rtl022_control_t / 308 | RTL-001.rtl022_control_o | RTL-022.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl022_status_i | input | dfc_rtl022_status_t / 137 | RTL-022.status_o | RTL-001.rtl022_status_i; RTL-002.module_ready_i[21]; RTL-002.module_fault_i[21] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl023_control_o | output | dfc_rtl023_control_t / 34 | RTL-001.rtl023_control_o | RTL-023.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl023_status_i | input | dfc_rtl023_status_t / 75 | RTL-023.status_o | RTL-001.rtl023_status_i; RTL-002.module_ready_i[22]; RTL-002.module_fault_i[22] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| rtl024_control_o | output | dfc_rtl024_control_t / 278 | RTL-001.rtl024_control_o | RTL-024.control_i | CORE_CLK / core_rst_n | registered configuration and one-cycle command members / generated field resets | same-domain |
| rtl024_status_i | input | dfc_rtl024_status_t / 467 | RTL-024.status_o | RTL-001.rtl024_status_i; RTL-002.module_ready_i[23]; RTL-002.module_fault_i[23] | CORE_CLK / core_rst_n | registered/coherent status / generated field resets | same-domain |
| irq_req_o | output | logic / 1 | RTL-001.irq_req_o | RTL-003.irq_source_i[21] | CORE_CLK / core_rst_n | level; active until source condition/clear semantics permit / 0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-001.timestamp_i | CORE_CLK / core_rst_n | registered time sample / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-001.evt_valid_o | RTL-005.evt_valid_i[0] | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[0] | RTL-001.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-001.evt_record_o | RTL-005.evt_record_i[0] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| status_o | output | dfc_rtl001_status_t / 19 | RTL-001.status_o | RTL-002.module_ready_i[0]; RTL-002.module_fault_i[0]; RTL-001 host-status readback logic | CORE_CLK / core_rst_n | registered/coherent status / ready=0; fault=0; event_overflow=0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-001.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-001.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| route_tx_msg_valid_o | output | logic / 1 | RTL-001.route_tx_msg_valid_o | RTL-021.source_valid_i[3] | CORE_CLK / core_rst_n | valid/ready atomic message transfer / inactive zero | same-domain |
| route_tx_msg_ready_i | input | logic / 1 | RTL-021.source_ready_o[3] | RTL-001.route_tx_msg_ready_i | CORE_CLK / core_rst_n | valid/ready atomic message transfer / inactive zero | same-domain |
| route_tx_msg_record_o | output | dfc_message_record_t / 192 | RTL-001.route_tx_msg_record_o | RTL-021.source_record_i[3] | CORE_CLK / core_rst_n | valid/ready atomic message transfer / inactive zero | same-domain |
| route_rx_msg_valid_i | input | logic / 1 | RTL-021.dest_valid_o[3] | RTL-001.route_rx_msg_valid_i | CORE_CLK / core_rst_n | valid/ready atomic message transfer / inactive zero | same-domain |
| route_rx_msg_ready_o | output | logic / 1 | RTL-001.route_rx_msg_ready_o | RTL-021.dest_ready_i[3] | CORE_CLK / core_rst_n | valid/ready atomic message transfer / inactive zero | same-domain |
| route_rx_msg_record_i | input | dfc_message_record_t / 192 | RTL-021.dest_record_o[3] | RTL-001.route_rx_msg_record_i | CORE_CLK / core_rst_n | valid/ready atomic message transfer / inactive zero | same-domain |
| event_condition_enable_o | output | logic [23:0][63:0] / 1536 | RTL-001 mask storage | RTL-001 internal and RTL-002 through RTL-024 condition gates | CORE_CLK / core_rst_n | registered subcondition masks; reserved bits zero / 0 | same-domain |
| irq_condition_enable_o | output | logic [23:0][63:0] / 1536 | RTL-001 mask storage | RTL-001 internal and RTL-002 through RTL-024 condition gates | CORE_CLK / core_rst_n | registered subcondition masks; reserved bits zero / 0 | same-domain |

### RTL-002 - System Control Logic (24 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-002.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-002.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[1] | RTL-002.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl002_control_t / 60 | RTL-001.rtl002_control_o | RTL-002.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl002_status_t / 112 | RTL-002.status_o | RTL-001.rtl002_status_i; RTL-002.module_ready_i[1]; RTL-002.module_fault_i[1] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-002.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-002.evt_valid_o | RTL-005.evt_valid_i[1] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[1] | RTL-002.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-002.evt_record_o | RTL-005.evt_record_i[1] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-002.irq_req_o | RTL-003.irq_source_i[0] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| module_ready_i | input | logic / 24 | RTL-(i+1).status_o.ready for i=0..23 | RTL-002.module_ready_i[23:0] | CORE_CLK / core_rst_n | readiness vector / 0 | same-domain |
| module_fault_i | input | logic / 24 | RTL-(i+1).status_o.fault for i=0..23 | RTL-002.module_fault_i[23:0] | CORE_CLK / core_rst_n | fault vector / 0 | same-domain |
| module_reset_o | output | logic / 24 | RTL-002.module_reset_o[23:0] | RTL-002 through RTL-023 local-reset inputs; bits 0 and 23 have no child local-reset consumer | CORE_CLK / core_rst_n | qualified reset request per ARCH-RST-004; bit 0 is serviced by ARCH-RST-005 and bit 23 by RTL-024 integration reset control / 0 | same-domain |
| operating_state_o | output | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-001.operating_state_i; RTL-003.operating_state_i; RTL-004.operating_state_i; RTL-005.operating_state_i; RTL-006.operating_state_i; RTL-007.operating_state_i; RTL-008.operating_state_i; RTL-009.operating_state_i; RTL-010.operating_state_i; RTL-011.operating_state_i; RTL-012.operating_state_i; RTL-013.operating_state_i; RTL-014.operating_state_i; RTL-015.operating_state_i; RTL-016.operating_state_i; RTL-017.operating_state_i; RTL-018.operating_state_i; RTL-019.operating_state_i; RTL-020.operating_state_i; RTL-021.operating_state_i; RTL-022.operating_state_i; RTL-023.operating_state_i; RTL-024.operating_state_i | CORE_CLK / core_rst_n | registered primary state / RESET_ACTIVE | same-domain |
| observational_mode_o | output | logic / 1 | RTL-002.observational_mode_o | RTL-001.observational_mode_i; RTL-003.observational_mode_i; RTL-004.observational_mode_i; RTL-005.observational_mode_i; RTL-006.observational_mode_i; RTL-007.observational_mode_i; RTL-008.observational_mode_i; RTL-009.observational_mode_i; RTL-010.observational_mode_i; RTL-011.observational_mode_i; RTL-012.observational_mode_i; RTL-013.observational_mode_i; RTL-014.observational_mode_i; RTL-015.observational_mode_i; RTL-016.observational_mode_i; RTL-017.observational_mode_i; RTL-018.observational_mode_i; RTL-019.observational_mode_i; RTL-020.observational_mode_i; RTL-021.observational_mode_i; RTL-022.observational_mode_i; RTL-023.observational_mode_i; RTL-024.observational_mode_i | CORE_CLK / core_rst_n | orthogonal mode / 1 | same-domain |
| degraded_req_i | input | logic / 1 | RTL-013.degraded_req_o | RTL-002.degraded_req_i | CORE_CLK / core_rst_n | qualified state request / 0 | same-domain |
| faulted_req_i | input | logic / 1 | RTL-013.faulted_req_o | RTL-002.faulted_req_i | CORE_CLK / core_rst_n | qualified state request / 0 | same-domain |
| effective_operational_enable_o | output | logic / 1 | RTL-002.effective_operational_enable_o | RTL-006.effective_operational_enable_i; RTL-016.effective_operational_enable_i; RTL-018.effective_operational_enable_i; RTL-019.effective_operational_enable_i; RTL-020.effective_operational_enable_i; RTL-021.effective_operational_enable_i; RTL-022.effective_operational_enable_i; RTL-023.effective_operational_enable_i; RTL-024.effective_operational_enable_i | CORE_CLK / core_rst_n | registered: OPERATIONAL_ENABLE && INIT_COMPLETE && !INIT_FAILED && (NORMAL ││ DEGRADED) && !OBSERVATIONAL_MODE && !TEST_DEBUG / 0 | same-domain |
| module_enable_o | output | logic / 24 | RTL-002.module_enable_o[23:0] | RTL-006.module_enable_i; RTL-007.module_enable_i; RTL-008.module_enable_i; RTL-009.module_enable_i; RTL-010.module_enable_i; RTL-011.module_enable_i; RTL-017.module_enable_i; RTL-018.module_enable_i; RTL-019.module_enable_i; RTL-020.module_enable_i; RTL-021.module_enable_i; RTL-022.module_enable_i; RTL-023.module_enable_i | CORE_CLK / core_rst_n | registered SUBSYS_ENABLE bitmap; mandatory bits fixed, optional bits configurable / 0x80F81F | same-domain |
| global_irq_enable_o | output | logic / 1 | RTL-002.global_irq_enable_o | RTL-003.global_irq_enable_i | CORE_CLK / core_rst_n | registered aggregate-output gate; raw and pending evidence preserved / 0 | same-domain |
| global_event_enable_o | output | logic / 1 | RTL-002.global_event_enable_o | RTL-005.global_event_enable_i | CORE_CLK / core_rst_n | registered normal-event acceptance gate; safety and overflow evidence bypass / 1 | same-domain |
| test_active_i | input | logic / 1 | RTL-024.test_active_o | RTL-002.test_active_i | CORE_CLK / core_rst_n | registered authorized test-active state / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[1] | RTL-002 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[1] | RTL-002 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-003 - Interrupt Controller (16 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-003.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-003.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[2] | RTL-003.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl003_control_t / 129 | RTL-001.rtl003_control_o | RTL-003.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl003_status_t / 153 | RTL-003.status_o | RTL-001.rtl003_status_i; RTL-002.module_ready_i[2]; RTL-002.module_fault_i[2] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-003.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-003.evt_valid_o | RTL-005.evt_valid_i[2] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[2] | RTL-003.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-003.evt_record_o | RTL-005.evt_record_i[2] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_source_i | input | logic / 32 | ARCH Table 90 fixed producers for bits 0..23; constant_zero[31:24] | RTL-003.irq_source_i[31:0] | CORE_CLK / core_rst_n | fixed source vector / 0 | same-domain |
| aggregate_pending_o | output | logic / 1 | RTL-003.aggregate_pending_o | RTL-024.aggregate_pending_i | CORE_CLK / core_rst_n | active-high level / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-003.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-003.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| global_irq_enable_i | input | logic / 1 | RTL-002.global_irq_enable_o | RTL-003.global_irq_enable_i | CORE_CLK / core_rst_n | gates only active-low external aggregate assertion; raw/pending state retained / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[2] | RTL-003 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[2] | RTL-003 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-004 - Timestamp Engine (14 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-004.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-004.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[3] | RTL-004.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl004_control_t / 73 | RTL-001.rtl004_control_o | RTL-004.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl004_status_t / 169 | RTL-004.status_o | RTL-001.rtl004_status_i; RTL-002.module_ready_i[3]; RTL-002.module_fault_i[3] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-004.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-004.evt_valid_o | RTL-005.evt_valid_i[3] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[3] | RTL-004.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-004.evt_record_o | RTL-005.evt_record_i[3] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| timestamp_o | output | logic / 64 | RTL-004.timestamp_o | RTL-001.timestamp_i; RTL-002.timestamp_i; RTL-003.timestamp_i; RTL-004.timestamp_i; RTL-005.timestamp_i; RTL-006.timestamp_i; RTL-007.timestamp_i; RTL-008.timestamp_i; RTL-009.timestamp_i; RTL-010.timestamp_i; RTL-011.timestamp_i; RTL-012.timestamp_i; RTL-013.timestamp_i; RTL-014.timestamp_i; RTL-015.timestamp_i; RTL-016.timestamp_i; RTL-017.timestamp_i; RTL-018.timestamp_i; RTL-019.timestamp_i; RTL-020.timestamp_i; RTL-021.timestamp_i; RTL-022.timestamp_i; RTL-023.timestamp_i; RTL-024.timestamp_i | CORE_CLK / core_rst_n | registered time / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-004.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-004.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[3] | RTL-004 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[3] | RTL-004 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-005 - Event Logger (19 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-005.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-005.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[4] | RTL-005.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl005_control_t / 128 | RTL-001.rtl005_control_o | RTL-005.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl005_status_t / 268 | RTL-005.status_o | RTL-001.rtl005_status_i; RTL-002.module_ready_i[4]; RTL-002.module_fault_i[4] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-005.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-005.evt_valid_o | RTL-005.evt_valid_i[4] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[4] | RTL-005.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-005.evt_record_o | RTL-005.evt_record_i[4] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-005.irq_req_o | RTL-003.irq_source_i[1] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-005.fault_req_o | RTL-013.fault_source_i[5] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| evt_valid_i | input | logic / 24 | RTL-(i+1).evt_valid_o for i=0..23 | RTL-005.evt_valid_i[23:0] | CORE_CLK / core_rst_n | 24 valid sources / 0 | same-domain |
| evt_ready_o | output | logic / 24 | RTL-005.evt_ready_o[23:0] | RTL-(i+1).evt_ready_i for i=0..23 | CORE_CLK / core_rst_n | one ready per arbitration result / 0 | same-domain |
| evt_record_i | input | dfc_event_record_t[24] / 3072 | RTL-(i+1).evt_record_o for i=0..23 | RTL-005.evt_record_i[23:0] | CORE_CLK / core_rst_n | 24 packed records / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-005.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-005.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| global_event_enable_i | input | logic / 1 | RTL-002.global_event_enable_o | RTL-005.global_event_enable_i | CORE_CLK / core_rst_n | gates normal event acceptance; SAFETY and OVERFLOW_DROPPED evidence bypass / 1 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[4] | RTL-005 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[4] | RTL-005 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-006 - GPIO Controller (20 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-006.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-006.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[5] | RTL-006.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl006_control_t / 123 | RTL-001.rtl006_control_o | RTL-006.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl006_status_t / 83 | RTL-006.status_o | RTL-001.rtl006_status_i; RTL-002.module_ready_i[5]; RTL-002.module_fault_i[5] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-006.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-006.evt_valid_o | RTL-005.evt_valid_i[5] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[5] | RTL-006.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-006.evt_record_o | RTL-005.evt_record_i[5] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-006.irq_req_o | RTL-003.irq_source_i[2] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| gpio_i | input | logic / 8 | RTL-024.gpio_in_o | RTL-006.gpio_i | CORE_CLK / core_rst_n | two-stage synchronized/qualified / 0 | CDC-GPIO |
| gpio_o | output | logic / 8 | RTL-006.gpio_o | RTL-024.gpio_out_i | CORE_CLK / core_rst_n | registered output / 0 | same-domain |
| gpio_oe_o | output | logic / 8 | RTL-006.gpio_oe_o | RTL-024.gpio_oe_i | CORE_CLK / core_rst_n | registered output-enable / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-006.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-006.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| route_gpio_req_i | input | logic / 8 | RTL-023.route_dest_o[8:1] | RTL-006.route_gpio_req_i[7:0] | CORE_CLK / core_rst_n | qualified route request / 0 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[5] | RTL-006.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| effective_operational_enable_i | input | logic / 1 | RTL-002.effective_operational_enable_o | RTL-006.effective_operational_enable_i | CORE_CLK / core_rst_n | registered operational-action permission; low suppresses externally effective action / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[5] | RTL-006 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[5] | RTL-006 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-007 - Rotor RPM Monitor (17 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-007.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-007.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[6] | RTL-007.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl007_control_t / 135 | RTL-001.rtl007_control_o | RTL-007.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl007_status_t / 73 | RTL-007.status_o | RTL-001.rtl007_status_i; RTL-002.module_ready_i[6]; RTL-002.module_fault_i[6] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-007.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-007.evt_valid_o | RTL-005.evt_valid_i[6] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[6] | RTL-007.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-007.evt_record_o | RTL-005.evt_record_i[6] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-007.irq_req_o | RTL-003.irq_source_i[8] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-007.fault_req_o | RTL-013.fault_source_i[6] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| rotor_i | input | logic / 1 | RTL-024.rotor_o | RTL-007.rotor_i | CORE_CLK / core_rst_n | synchronized edge input / 0 | CDC-PULSE |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-007.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-007.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[6] | RTL-007.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[6] | RTL-007 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[6] | RTL-007 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-008 - Engine RPM Monitor (17 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-008.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-008.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[7] | RTL-008.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl008_control_t / 136 | RTL-001.rtl008_control_o | RTL-008.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl008_status_t / 73 | RTL-008.status_o | RTL-001.rtl008_status_i; RTL-002.module_ready_i[7]; RTL-002.module_fault_i[7] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-008.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-008.evt_valid_o | RTL-005.evt_valid_i[7] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[7] | RTL-008.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-008.evt_record_o | RTL-005.evt_record_i[7] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-008.irq_req_o | RTL-003.irq_source_i[9] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-008.fault_req_o | RTL-013.fault_source_i[7] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| engine_i | input | logic / 1 | RTL-024.engine_o | RTL-008.engine_i | CORE_CLK / core_rst_n | synchronized edge input / 0 | CDC-PULSE |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-008.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-008.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[7] | RTL-008.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[7] | RTL-008 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[7] | RTL-008 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-009 - Pulse/Frequency Measurement (17 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-009.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-009.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[8] | RTL-009.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl009_control_t / 335 | RTL-001.rtl009_control_o | RTL-009.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl009_status_t / 159 | RTL-009.status_o | RTL-001.rtl009_status_i; RTL-002.module_ready_i[8]; RTL-002.module_fault_i[8] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-009.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-009.evt_valid_o | RTL-005.evt_valid_i[8] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[8] | RTL-009.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-009.evt_record_o | RTL-005.evt_record_i[8] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-009.irq_req_o | RTL-003.irq_source_i[10] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-009.fault_req_o | RTL-013.fault_source_i[8] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| pulse_i | input | logic / 2 | RTL-024.pulse_o | RTL-009.pulse_i | CORE_CLK / core_rst_n | synchronized edge inputs / 0 | CDC-PULSE |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-009.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-009.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[8] | RTL-009.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[8] | RTL-009 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[8] | RTL-009 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-010 - Sensor Monitor Interface (16 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-010.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-010.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[9] | RTL-010.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl010_control_t / 346 | RTL-001.rtl010_control_o | RTL-010.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl010_status_t / 225 | RTL-010.status_o | RTL-001.rtl010_status_i; RTL-002.module_ready_i[9]; RTL-002.module_fault_i[9] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-010.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-010.evt_valid_o | RTL-005.evt_valid_i[9] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[9] | RTL-010.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-010.evt_record_o | RTL-005.evt_record_i[9] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-010.irq_req_o | RTL-003.irq_source_i[11] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-010.fault_req_o | RTL-013.fault_source_i[9] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-010.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-010.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[9] | RTL-010.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[9] | RTL-010 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[9] | RTL-010 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-011 - System Health Monitor (17 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-011.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-011.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[10] | RTL-011.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl011_control_t / 121 | RTL-001.rtl011_control_o | RTL-011.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl011_status_t / 84 | RTL-011.status_o | RTL-001.rtl011_status_i; RTL-002.module_ready_i[10]; RTL-002.module_fault_i[10] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-011.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-011.evt_valid_o | RTL-005.evt_valid_i[10] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[10] | RTL-011.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-011.evt_record_o | RTL-005.evt_record_i[10] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-011.irq_req_o | RTL-003.irq_source_i[12] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-011.fault_req_o | RTL-013.fault_source_i[4] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| health_i | input | logic / 8 | RTL-024.health_in_o | RTL-011.health_i | CORE_CLK / core_rst_n | synchronized/qualified / 0 | CDC-HEALTH |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-011.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-011.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[10] | RTL-011.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[10] | RTL-011 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[10] | RTL-011 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-012 - Watchdog Manager (17 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-012.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-012.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[11] | RTL-012.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl012_control_t / 111 | RTL-001.rtl012_control_o | RTL-012.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl012_status_t / 58 | RTL-012.status_o | RTL-001.rtl012_status_i; RTL-002.module_ready_i[11]; RTL-002.module_fault_i[11] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-012.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-012.evt_valid_o | RTL-005.evt_valid_i[11] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[11] | RTL-012.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-012.evt_record_o | RTL-005.evt_record_i[11] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-012.irq_req_o | RTL-003.irq_source_i[13] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-012.fault_req_o | RTL-013.fault_source_i[0] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| response_req_o | output | dfc_safety_response_req_t / 8 | RTL-012.response_req_o | RTL-016.response_req_i[0] | CORE_CLK / core_rst_n | finite code with valid/source / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-012.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-012.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| service_activity_o | output | logic / 1 | RTL-012.service_activity_o | RTL-015.activity_i[1] | CORE_CLK / core_rst_n | one CORE_CLK pulse on qualified service acceptance / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[11] | RTL-012 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[11] | RTL-012 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-013 - Fault Manager (19 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-013.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-013.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[12] | RTL-013.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl013_control_t / 112 | RTL-001.rtl013_control_o | RTL-013.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl013_status_t / 106 | RTL-013.status_o | RTL-001.rtl013_status_i; RTL-002.module_ready_i[12]; RTL-002.module_fault_i[12] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-013.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-013.evt_valid_o | RTL-005.evt_valid_i[12] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[12] | RTL-013.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-013.evt_record_o | RTL-005.evt_record_i[12] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-013.irq_req_o | RTL-003.irq_source_i[14] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_source_i | input | logic / 32 | Fault source endpoint matrix exact fixed producers bits 0..16, each a dedicated module fault_req_o (bit 10 is RTL-017.fault_req_o); constant_zero[31:17] | RTL-013.fault_source_i[31:0] | CORE_CLK / core_rst_n | fixed source vector / 0 | same-domain |
| degraded_req_o | output | logic / 1 | RTL-013.degraded_req_o | RTL-002.degraded_req_i | CORE_CLK / core_rst_n | level request / 0 | same-domain |
| faulted_req_o | output | logic / 1 | RTL-013.faulted_req_o | RTL-002.faulted_req_i | CORE_CLK / core_rst_n | latched request / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-013.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-013.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| response_req_o | output | dfc_safety_response_req_t / 8 | RTL-013.response_req_o | RTL-016.response_req_i[1] | CORE_CLK / core_rst_n | valid request record / zero | same-domain |
| safety_inhibit_o | output | logic / 4 | RTL-013 nonrecoverable-active reduction | RTL-016.fault_inhibit_i | CORE_CLK / core_rst_n | all four bits equal OR of active nonrecoverable fault sources / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[12] | RTL-013 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[12] | RTL-013 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-014 - Interlock Engine (19 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-014.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-014.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[13] | RTL-014.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl014_control_t / 513 | RTL-001.rtl014_control_o | RTL-014.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl014_status_t / 115 | RTL-014.status_o | RTL-001.rtl014_status_i; RTL-002.module_ready_i[13]; RTL-002.module_fault_i[13] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-014.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-014.evt_valid_o | RTL-005.evt_valid_i[13] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[13] | RTL-014.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-014.evt_record_o | RTL-005.evt_record_i[13] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-014.irq_req_o | RTL-003.irq_source_i[15] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-014.fault_req_o | RTL-013.fault_source_i[1] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| interlock_terms_i | input | logic / 64 | dragon_core_top.internal_source_vector[63:0] | RTL-014.interlock_terms_i[63:0] | CORE_CLK / core_rst_n | stable qualified terms / 0 | same-domain |
| interlock_satisfied_o | output | logic / 8 | RTL-014.interlock_satisfied_o | RTL-016.interlock_satisfied_i | CORE_CLK / core_rst_n | registered status / 0 | same-domain |
| interlock_inhibit_o | output | logic / 8 | RTL-014.interlock_inhibit_o | RTL-016.interlock_inhibit_i | CORE_CLK / core_rst_n | registered inhibit / 1 | same-domain |
| response_req_o | output | dfc_safety_response_req_t / 8 | RTL-014.response_req_o | RTL-016.response_req_i[2] | CORE_CLK / core_rst_n | finite code with valid/source / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-014.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-014.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[13] | RTL-014 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[13] | RTL-014 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-015 - Lost-Link Supervisor (17 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-015.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-015.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[14] | RTL-015.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl015_control_t / 961 | RTL-001.rtl015_control_o | RTL-015.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl015_status_t / 75 | RTL-015.status_o | RTL-001.rtl015_status_i; RTL-002.module_ready_i[14]; RTL-002.module_fault_i[14] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-015.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-015.evt_valid_o | RTL-005.evt_valid_i[14] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[14] | RTL-015.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-015.evt_record_o | RTL-005.evt_record_i[14] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-015.irq_req_o | RTL-003.irq_source_i[16] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-015.fault_req_o | RTL-013.fault_source_i[2] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| activity_i | input | logic / 8 | RTL-024 activity vector: accepted host command, ARINC RX word, CAN RX frame, UART RX byte, any qualified GPIO transition, any qualified health transition, synchronized user-input transition, accepted external watchdog-service pulse | RTL-015.activity_i[7:0] | CORE_CLK / core_rst_n | exact source order from ARCH-SAFE-007; one-cycle qualified activity / 0 | same-domain |
| response_req_o | output | dfc_safety_response_req_t / 8 | RTL-015.response_req_o | RTL-016.response_req_i[3] | CORE_CLK / core_rst_n | finite code with valid/source / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-015.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-015.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[14] | RTL-015 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[14] | RTL-015 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-016 - Safety Output Controller (22 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-016.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-016.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[15] | RTL-016.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl016_control_t / 226 | RTL-001.rtl016_control_o | RTL-016.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl016_status_t / 52 | RTL-016.status_o | RTL-001.rtl016_status_i; RTL-002.module_ready_i[15]; RTL-002.module_fault_i[15] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-016.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-016.evt_valid_o | RTL-005.evt_valid_i[15] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[15] | RTL-016.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-016.evt_record_o | RTL-005.evt_record_i[15] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-016.irq_req_o | RTL-003.irq_source_i[17] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-016.fault_req_o | RTL-013.fault_source_i[3] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| response_req_i | input | dfc_safety_response_req_t[4] / 32 | RTL-012.response_req_o; RTL-013.response_req_o; RTL-014.response_req_o; RTL-015.response_req_o | RTL-016.response_req_i[3:0] | CORE_CLK / core_rst_n | finite requests; deterministic priority / 0 | same-domain |
| interlock_satisfied_i | input | logic / 8 | RTL-014.interlock_satisfied_o | RTL-016.interlock_satisfied_i | CORE_CLK / core_rst_n | registered interlock state / 0 | same-domain |
| interlock_inhibit_i | input | logic / 8 | RTL-014.interlock_inhibit_o | RTL-016.interlock_inhibit_i | CORE_CLK / core_rst_n | registered inhibits / 1 | same-domain |
| safety_out_o | output | logic / 4 | RTL-016.safety_out_o | RTL-024 safety pad gate | CORE_CLK / core_rst_n | registered configured inactive/active levels; reset inactive low / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-016.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-016.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| effective_operational_enable_i | input | logic / 1 | RTL-002.effective_operational_enable_o | RTL-016.effective_operational_enable_i | CORE_CLK / core_rst_n | registered operational-action permission; low suppresses externally effective action / 0 | same-domain |
| fault_inhibit_i | input | logic / 4 | RTL-013.safety_inhibit_o | RTL-016 fault gate | CORE_CLK / core_rst_n | per-channel active-high inhibit / 0 | same-domain |
| test_inhibit_i | input | logic / 1 | RTL-024 physical test authorization OR test-active | RTL-016 test gate | CORE_CLK / core_rst_n | active-high inhibit; asynchronous assertion is applied again in RTL-024 pad-safe gate / 1 during reset | CDC-TEST-001 |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[15] | RTL-016 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[15] | RTL-016 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-017 - ARINC 429 Receive Interface (33 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-017.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-017.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[16] | RTL-017.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl017_control_t / 105 | RTL-001.rtl017_control_o | RTL-017.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl017_status_t / 256 | RTL-017.status_o | RTL-001.rtl017_status_i; RTL-002.module_ready_i[16]; RTL-002.module_fault_i[16] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-017.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-017.evt_valid_o | RTL-005.evt_valid_i[16] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[16] | RTL-017.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-017.evt_record_o | RTL-005.evt_record_i[16] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-017.irq_req_o | RTL-003.irq_source_i[3] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| msg_valid_o | output | logic / 1 | RTL-017.msg_valid_o | RTL-021.source_valid_i[0] | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| msg_ready_i | input | logic / 1 | RTL-021.source_ready_o[0] | RTL-017.msg_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| msg_record_o | output | dfc_message_record_t / 192 | RTL-017.msg_record_o | RTL-021.source_record_i[0] | CORE_CLK / core_rst_n | stable while stalled / 0 | same-domain |
| rx_word_valid_i | input | logic / 1 | RTL-024.arinc_rx_adapter.rx_word_valid_o | RTL-017.rx_word_valid_i | CORE_CLK / core_rst_n | one-cycle word indication / 0 | same-domain; upstream CDC-ARINC completed in RTL-024 receive adapter |
| rx_word_i | input | logic / 32 | RTL-024.arinc_rx_adapter.rx_word_o | RTL-017.rx_word_i | CORE_CLK / core_rst_n | stable for valid cycle / 0 | same-domain; upstream CDC-ARINC completed in RTL-024 receive adapter |
| rx_parity_error_i | input | logic / 1 | RTL-024.arinc_rx_adapter.rx_parity_error_o | RTL-017.rx_parity_error_i | CORE_CLK / core_rst_n | aligned metadata / 0 | same-domain; upstream CDC-ARINC completed in RTL-024 receive adapter |
| rx_framing_error_i | input | logic / 1 | RTL-024.arinc_rx_adapter.rx_framing_error_o | RTL-017.rx_framing_error_i | CORE_CLK / core_rst_n | aligned metadata / 0 | same-domain; upstream CDC-ARINC completed in RTL-024 receive adapter |
| rx_speed_high_i | input | logic / 1 | RTL-024.arinc_rx_adapter.rx_speed_high_o | RTL-017.rx_speed_high_i | CORE_CLK / core_rst_n | aligned metadata / 0 | same-domain; upstream CDC-ARINC completed in RTL-024 receive adapter |
| rx_adapter_overrun_i | input | logic / 1 | RTL-024.arinc_rx_adapter.rx_adapter_overrun_o | RTL-017.rx_adapter_overrun_i | CORE_CLK / core_rst_n | sticky/pulsed loss evidence / 0 | same-domain; upstream CDC-ARINC completed in RTL-024 receive adapter |
| arx_adapter_error_i | input | logic / 1 | RTL-024.arinc_rx_adapter.arx_adapter_error_o | RTL-017.arx_adapter_error_i | CORE_CLK / core_rst_n | registered same-domain adapter-error evidence / 0 | same-domain; upstream CDC-ARINC completed in RTL-024 receive adapter |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-017.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-017.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| activity_o | output | logic / 1 | RTL-017.activity_o | RTL-015.activity_i[2] | CORE_CLK / core_rst_n | one CORE_CLK pulse on qualified accepted unit of work / 0 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[16] | RTL-017.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-017.fault_req_o | RTL-013.fault_source_i[10] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| buf_req_valid_o | output | logic / 1 | RTL-017 queue engine | RTL-024 shared-buffer client 0 | CORE_CLK / core_rst_n | held until accepted / 0 | same-domain |
| buf_req_ready_i | input | logic / 1 | RTL-024 shared-buffer client 0 | RTL-017 queue engine | CORE_CLK / core_rst_n | request acceptance / 0 | same-domain |
| buf_req_o | output | dfc_buffer_req_t / 42 | RTL-017 queue engine | RTL-024 shared-buffer client 0 | CORE_CLK / core_rst_n | stable while request stalled / 0 | same-domain |
| buf_rsp_valid_i | input | logic / 1 | RTL-024 shared-buffer client 0 | RTL-017 queue engine | CORE_CLK / core_rst_n | one response per accepted request / 0 | same-domain |
| buf_rsp_ready_o | output | logic / 1 | RTL-017 queue engine | RTL-024 shared-buffer client 0 | CORE_CLK / core_rst_n | response acceptance / 0 | same-domain |
| buf_rsp_i | input | dfc_buffer_rsp_t / 34 | RTL-024 shared-buffer client 0 | RTL-017 queue engine | CORE_CLK / core_rst_n | stable while response stalled / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[16] | RTL-017 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[16] | RTL-017 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-018 - ARINC 429 Transmit Interface (28 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-018.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-018.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[17] | RTL-018.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl018_control_t / 163 | RTL-001.rtl018_control_o | RTL-018.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl018_status_t / 127 | RTL-018.status_o | RTL-001.rtl018_status_i; RTL-002.module_ready_i[17]; RTL-002.module_fault_i[17] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-018.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-018.evt_valid_o | RTL-005.evt_valid_i[17] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[17] | RTL-018.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-018.evt_record_o | RTL-005.evt_record_i[17] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-018.irq_req_o | RTL-003.irq_source_i[4] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-018.fault_req_o | RTL-013.fault_source_i[11] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| msg_valid_i | input | logic / 1 | RTL-021.dest_valid_o[0] | RTL-018.msg_valid_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| msg_ready_o | output | logic / 1 | RTL-018.msg_ready_o | RTL-021.dest_ready_i[0] | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| msg_record_i | input | dfc_message_record_t / 192 | RTL-021.dest_record_o[0] | RTL-018.msg_record_i | CORE_CLK / core_rst_n | stable while stalled / 0 | same-domain |
| arinc_tx_ctrl_o | output | logic / 2 | RTL-018.arinc_tx_ctrl_o | RTL-024/pads | CORE_CLK / core_rst_n | registered serialized control / 0 | same-domain |
| atx_adapter_error_i | input | logic / 1 | RTL-024.atx_adapter_error_o | RTL-018.atx_adapter_error_i | CORE_CLK / core_rst_n | registered same-domain adapter-error evidence / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-018.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-018.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[17] | RTL-018.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| effective_operational_enable_i | input | logic / 1 | RTL-002.effective_operational_enable_o | RTL-018.effective_operational_enable_i | CORE_CLK / core_rst_n | registered operational-action permission; low suppresses externally effective action / 0 | same-domain |
| buf_req_valid_o | output | logic / 1 | RTL-018 queue engine | RTL-024 shared-buffer client 1 | CORE_CLK / core_rst_n | held until accepted / 0 | same-domain |
| buf_req_ready_i | input | logic / 1 | RTL-024 shared-buffer client 1 | RTL-018 queue engine | CORE_CLK / core_rst_n | request acceptance / 0 | same-domain |
| buf_req_o | output | dfc_buffer_req_t / 42 | RTL-018 queue engine | RTL-024 shared-buffer client 1 | CORE_CLK / core_rst_n | stable while request stalled / 0 | same-domain |
| buf_rsp_valid_i | input | logic / 1 | RTL-024 shared-buffer client 1 | RTL-018 queue engine | CORE_CLK / core_rst_n | one response per accepted request / 0 | same-domain |
| buf_rsp_ready_o | output | logic / 1 | RTL-018 queue engine | RTL-024 shared-buffer client 1 | CORE_CLK / core_rst_n | response acceptance / 0 | same-domain |
| buf_rsp_i | input | dfc_buffer_rsp_t / 34 | RTL-024 shared-buffer client 1 | RTL-018 queue engine | CORE_CLK / core_rst_n | stable while response stalled / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[17] | RTL-018 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[17] | RTL-018 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-019 - Classical CAN Interface (33 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-019.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-019.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[18] | RTL-019.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl019_control_t / 204 | RTL-001.rtl019_control_o | RTL-019.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl019_status_t / 326 | RTL-019.status_o | RTL-001.rtl019_status_i; RTL-002.module_ready_i[18]; RTL-002.module_fault_i[18] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-019.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-019.evt_valid_o | RTL-005.evt_valid_i[18] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[18] | RTL-019.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-019.evt_record_o | RTL-005.evt_record_i[18] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-019.irq_req_o | RTL-003.irq_source_i[5] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-019.fault_req_o | RTL-013.fault_source_i[12] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| can_rx_i | input | logic / 1 | RTL-024.can_rx_o | RTL-019.can_rx_i | CORE_CLK / core_rst_n | synchronized sampled bus / 1 | CDC-CAN |
| can_tx_o | output | logic / 1 | RTL-019.can_tx_o | RTL-024.can_tx_i | CORE_CLK / core_rst_n | registered protocol output / 1 | same-domain |
| can_transceiver_error_i | input | logic / 1 | RTL-024.can_transceiver_error_o | RTL-019.can_transceiver_error_i | CORE_CLK / core_rst_n | registered same-domain transceiver-error evidence / 0 | same-domain |
| rx_msg_valid_o | output | logic / 1 | RTL-019.rx_msg_valid_o | RTL-021.source_valid_i[1] | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| rx_msg_ready_i | input | logic / 1 | RTL-021.source_ready_o[1] | RTL-019.rx_msg_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| rx_msg_record_o | output | dfc_message_record_t / 192 | RTL-019.rx_msg_record_o | RTL-021.source_record_i[1] | CORE_CLK / core_rst_n | stable while stalled / 0 | same-domain |
| tx_msg_valid_i | input | logic / 1 | RTL-021.dest_valid_o[1] | RTL-019.tx_msg_valid_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| tx_msg_ready_o | output | logic / 1 | RTL-019.tx_msg_ready_o | RTL-021.dest_ready_i[1] | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| tx_msg_record_i | input | dfc_message_record_t / 192 | RTL-021.dest_record_o[1] | RTL-019.tx_msg_record_i | CORE_CLK / core_rst_n | stable while stalled / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-019.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-019.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| activity_o | output | logic / 1 | RTL-019.activity_o | RTL-015.activity_i[3] | CORE_CLK / core_rst_n | one CORE_CLK pulse on qualified accepted unit of work / 0 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[18] | RTL-019.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| effective_operational_enable_i | input | logic / 1 | RTL-002.effective_operational_enable_o | RTL-019.effective_operational_enable_i | CORE_CLK / core_rst_n | registered operational-action permission; low suppresses externally effective action / 0 | same-domain |
| buf_req_valid_o | output | logic / 1 | RTL-019 queue engine | RTL-024 shared-buffer client 2 | CORE_CLK / core_rst_n | held until accepted / 0 | same-domain |
| buf_req_ready_i | input | logic / 1 | RTL-024 shared-buffer client 2 | RTL-019 queue engine | CORE_CLK / core_rst_n | request acceptance / 0 | same-domain |
| buf_req_o | output | dfc_buffer_req_t / 42 | RTL-019 queue engine | RTL-024 shared-buffer client 2 | CORE_CLK / core_rst_n | stable while request stalled / 0 | same-domain |
| buf_rsp_valid_i | input | logic / 1 | RTL-024 shared-buffer client 2 | RTL-019 queue engine | CORE_CLK / core_rst_n | one response per accepted request / 0 | same-domain |
| buf_rsp_ready_o | output | logic / 1 | RTL-019 queue engine | RTL-024 shared-buffer client 2 | CORE_CLK / core_rst_n | response acceptance / 0 | same-domain |
| buf_rsp_i | input | dfc_buffer_rsp_t / 34 | RTL-024 shared-buffer client 2 | RTL-019 queue engine | CORE_CLK / core_rst_n | stable while response stalled / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[18] | RTL-019 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[18] | RTL-019 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-020 - UART Interface (32 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-020.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-020.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[19] | RTL-020.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl020_control_t / 216 | RTL-001.rtl020_control_o | RTL-020.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl020_status_t / 217 | RTL-020.status_o | RTL-001.rtl020_status_i; RTL-002.module_ready_i[19]; RTL-002.module_fault_i[19] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-020.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-020.evt_valid_o | RTL-005.evt_valid_i[19] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[19] | RTL-020.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-020.evt_record_o | RTL-005.evt_record_i[19] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-020.irq_req_o | RTL-003.irq_source_i[6] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-020.fault_req_o | RTL-013.fault_source_i[13] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| uart_rx_i | input | logic / 1 | RTL-024.uart_rx_o | RTL-020.uart_rx_i | CORE_CLK / core_rst_n | synchronized sampled serial / 1 | CDC-UART |
| uart_tx_o | output | logic / 1 | RTL-020.uart_tx_o | RTL-024.uart_tx_i | CORE_CLK / core_rst_n | registered serial output / 1 | same-domain |
| rx_msg_valid_o | output | logic / 1 | RTL-020.rx_msg_valid_o | RTL-021.source_valid_i[2] | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| rx_msg_ready_i | input | logic / 1 | RTL-021.source_ready_o[2] | RTL-020.rx_msg_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| rx_msg_record_o | output | dfc_message_record_t / 192 | RTL-020.rx_msg_record_o | RTL-021.source_record_i[2] | CORE_CLK / core_rst_n | stable while stalled / 0 | same-domain |
| tx_msg_valid_i | input | logic / 1 | RTL-021.dest_valid_o[2] | RTL-020.tx_msg_valid_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| tx_msg_ready_o | output | logic / 1 | RTL-020.tx_msg_ready_o | RTL-021.dest_ready_i[2] | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| tx_msg_record_i | input | dfc_message_record_t / 192 | RTL-021.dest_record_o[2] | RTL-020.tx_msg_record_i | CORE_CLK / core_rst_n | stable while stalled / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-020.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-020.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| activity_o | output | logic / 1 | RTL-020.activity_o | RTL-015.activity_i[4] | CORE_CLK / core_rst_n | one CORE_CLK pulse on qualified accepted unit of work / 0 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[19] | RTL-020.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| effective_operational_enable_i | input | logic / 1 | RTL-002.effective_operational_enable_o | RTL-020.effective_operational_enable_i | CORE_CLK / core_rst_n | registered operational-action permission; low suppresses externally effective action / 0 | same-domain |
| buf_req_valid_o | output | logic / 1 | RTL-020 queue engine | RTL-024 shared-buffer client 3 | CORE_CLK / core_rst_n | held until accepted / 0 | same-domain |
| buf_req_ready_i | input | logic / 1 | RTL-024 shared-buffer client 3 | RTL-020 queue engine | CORE_CLK / core_rst_n | request acceptance / 0 | same-domain |
| buf_req_o | output | dfc_buffer_req_t / 42 | RTL-020 queue engine | RTL-024 shared-buffer client 3 | CORE_CLK / core_rst_n | stable while request stalled / 0 | same-domain |
| buf_rsp_valid_i | input | logic / 1 | RTL-024 shared-buffer client 3 | RTL-020 queue engine | CORE_CLK / core_rst_n | one response per accepted request / 0 | same-domain |
| buf_rsp_ready_o | output | logic / 1 | RTL-020 queue engine | RTL-024 shared-buffer client 3 | CORE_CLK / core_rst_n | response acceptance / 0 | same-domain |
| buf_rsp_i | input | dfc_buffer_rsp_t / 34 | RTL-024 shared-buffer client 3 | RTL-020 queue engine | CORE_CLK / core_rst_n | stable while response stalled / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[19] | RTL-020 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[19] | RTL-020 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-021 - Databus Routing Engine (30 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-021.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-021.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[20] | RTL-021.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl021_control_t / 136 | RTL-001.rtl021_control_o | RTL-021.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl021_status_t / 338 | RTL-021.status_o | RTL-001.rtl021_status_i; RTL-002.module_ready_i[20]; RTL-002.module_fault_i[20] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-021.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-021.evt_valid_o | RTL-005.evt_valid_i[20] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[20] | RTL-021.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-021.evt_record_o | RTL-005.evt_record_i[20] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-021.irq_req_o | RTL-003.irq_source_i[7] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-021.fault_req_o | RTL-013.fault_source_i[14] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| source_valid_i | input | logic / 5 | RTL-017.msg_valid_o; RTL-019.rx_msg_valid_o; RTL-020.rx_msg_valid_o; RTL-001.route_tx_msg_valid_o; RTL-022.tx_msg_valid_o | RTL-021.source_valid_i[4:0] | CORE_CLK / core_rst_n | per-source valid / 0 | same-domain |
| source_ready_o | output | logic / 5 | RTL-021.source_ready_o[4:0] | RTL-017.msg_ready_i; RTL-019.rx_msg_ready_i; RTL-020.rx_msg_ready_i; RTL-001.route_tx_msg_ready_i; RTL-022.tx_msg_ready_i | CORE_CLK / core_rst_n | per-source ready / 0 | same-domain |
| source_record_i | input | dfc_message_record_t[5] / 960 | RTL-017.msg_record_o; RTL-019.rx_msg_record_o; RTL-020.rx_msg_record_o; RTL-001.route_tx_msg_record_o; RTL-022.tx_msg_record_o | RTL-021.source_record_i[4:0] | CORE_CLK / core_rst_n | stable while stalled / 0 | same-domain |
| dest_valid_o | output | logic / 5 | RTL-021.dest_valid_o[4:0] | RTL-018.msg_valid_i; RTL-019.tx_msg_valid_i; RTL-020.tx_msg_valid_i; RTL-001.route_rx_msg_valid_i; RTL-022.rx_msg_valid_i | CORE_CLK / core_rst_n | per-destination valid / 0 | same-domain |
| dest_ready_i | input | logic / 5 | RTL-018.msg_ready_o; RTL-019.tx_msg_ready_o; RTL-020.tx_msg_ready_o; RTL-001.route_rx_msg_ready_o; RTL-022.rx_msg_ready_o | RTL-021.dest_ready_i[4:0] | CORE_CLK / core_rst_n | per-destination ready / 0 | same-domain |
| dest_record_o | output | dfc_message_record_t[5] / 960 | RTL-021.dest_record_o[4:0] | RTL-018.msg_record_i; RTL-019.tx_msg_record_i; RTL-020.tx_msg_record_i; RTL-001.route_rx_msg_record_i; RTL-022.rx_msg_record_i | CORE_CLK / core_rst_n | stable while stalled / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-021.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-021.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| activity_o | output | logic / 1 | RTL-021.activity_o | RTL-015.activity_i[5] | CORE_CLK / core_rst_n | one CORE_CLK pulse on qualified accepted unit of work / 0 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[20] | RTL-021.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| effective_operational_enable_i | input | logic / 1 | RTL-002.effective_operational_enable_o | RTL-021.effective_operational_enable_i | CORE_CLK / core_rst_n | registered operational-action permission; low suppresses externally effective action / 0 | same-domain |
| buf_req_valid_o | output | logic / 1 | RTL-021 queue engine | RTL-024 shared-buffer client 4 | CORE_CLK / core_rst_n | held until accepted / 0 | same-domain |
| buf_req_ready_i | input | logic / 1 | RTL-024 shared-buffer client 4 | RTL-021 queue engine | CORE_CLK / core_rst_n | request acceptance / 0 | same-domain |
| buf_req_o | output | dfc_buffer_req_t / 42 | RTL-021 queue engine | RTL-024 shared-buffer client 4 | CORE_CLK / core_rst_n | stable while request stalled / 0 | same-domain |
| buf_rsp_valid_i | input | logic / 1 | RTL-024 shared-buffer client 4 | RTL-021 queue engine | CORE_CLK / core_rst_n | one response per accepted request / 0 | same-domain |
| buf_rsp_ready_o | output | logic / 1 | RTL-021 queue engine | RTL-024 shared-buffer client 4 | CORE_CLK / core_rst_n | response acceptance / 0 | same-domain |
| buf_rsp_i | input | dfc_buffer_rsp_t / 34 | RTL-024 shared-buffer client 4 | RTL-021 queue engine | CORE_CLK / core_rst_n | stable while response stalled / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[20] | RTL-021 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[20] | RTL-021 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-022 - User Logic Island (35 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-022.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-022.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[21] | RTL-022.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl022_control_t / 308 | RTL-001.rtl022_control_o | RTL-022.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl022_status_t / 137 | RTL-022.status_o | RTL-001.rtl022_status_i; RTL-002.module_ready_i[21]; RTL-002.module_fault_i[21] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-022.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-022.evt_valid_o | RTL-005.evt_valid_i[21] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[21] | RTL-022.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-022.evt_record_o | RTL-005.evt_record_i[21] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-022.irq_req_o | RTL-003.irq_source_i[18] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-022.fault_req_o | RTL-013.fault_source_i[15] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| user_i | input | logic / 4 | RTL-024.user_in_o | RTL-022.user_i | CORE_CLK / core_rst_n | synchronized/qualified / 0 | CDC-USER |
| user_o | output | logic / 4 | RTL-022.user_o | RTL-024.user_out_i | CORE_CLK / core_rst_n | registered bounded output / 0 | same-domain |
| user_oe_o | output | logic / 4 | RTL-022.user_oe_o | RTL-024 user-pad safe gate | CORE_CLK / core_rst_n | Revision A constant zero / 0 | same-domain |
| rx_msg_valid_i | input | logic / 1 | RTL-021.dest_valid_o[4] | RTL-022.rx_msg_valid_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| rx_msg_ready_o | output | logic / 1 | RTL-022.rx_msg_ready_o | RTL-021.dest_ready_i[4] | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| rx_msg_record_i | input | dfc_message_record_t / 192 | RTL-021.dest_record_o[4] | RTL-022.rx_msg_record_i | CORE_CLK / core_rst_n | stable while stalled / 0 | same-domain |
| tx_msg_valid_o | output | logic / 1 | RTL-022.tx_msg_valid_o | RTL-021.source_valid_i[4] | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| tx_msg_ready_i | input | logic / 1 | RTL-021.source_ready_o[4] | RTL-022.tx_msg_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| tx_msg_record_o | output | dfc_message_record_t / 192 | RTL-022.tx_msg_record_o | RTL-021.source_record_i[4] | CORE_CLK / core_rst_n | stable while stalled / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-022.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-022.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| route_user_req_i | input | logic / 4 | RTL-023.route_dest_o[12:9] | RTL-022.route_user_req_i[3:0] | CORE_CLK / core_rst_n | qualified route request / 0 | same-domain |
| route_term_i | input | logic / 8 | RTL-023.route_dest_o[20:13] | RTL-022.route_term_i[7:0] | CORE_CLK / core_rst_n | qualified user-logic term request / 0 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[21] | RTL-022.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| effective_operational_enable_i | input | logic / 1 | RTL-002.effective_operational_enable_o | RTL-022.effective_operational_enable_i | CORE_CLK / core_rst_n | registered operational-action permission; low suppresses externally effective action / 0 | same-domain |
| test_active_i | input | logic / 1 | RTL-024.test_active_o | RTL-022.test_active_i | CORE_CLK / core_rst_n | registered authorized test-active state / 0 | same-domain |
| buf_req_valid_o | output | logic / 1 | RTL-022 mailbox engine | RTL-024 shared-buffer client 5 | CORE_CLK / core_rst_n | held until accepted / 0 | same-domain |
| buf_req_ready_i | input | logic / 1 | RTL-024 shared-buffer client 5 | RTL-022 mailbox engine | CORE_CLK / core_rst_n | request acceptance / 0 | same-domain |
| buf_req_o | output | dfc_buffer_req_t / 42 | RTL-022 mailbox engine | RTL-024 shared-buffer client 5 | CORE_CLK / core_rst_n | stable while request stalled / 0 | same-domain |
| buf_rsp_valid_i | input | logic / 1 | RTL-024 shared-buffer client 5 | RTL-022 mailbox engine | CORE_CLK / core_rst_n | one response per accepted request / 0 | same-domain |
| buf_rsp_ready_o | output | logic / 1 | RTL-022 mailbox engine | RTL-024 shared-buffer client 5 | CORE_CLK / core_rst_n | response acceptance / 0 | same-domain |
| buf_rsp_i | input | dfc_buffer_rsp_t / 34 | RTL-024 shared-buffer client 5 | RTL-022 mailbox engine | CORE_CLK / core_rst_n | stable while response stalled / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[21] | RTL-022 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[21] | RTL-022 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-023 - User-Configurable Routing Logic (19 ports)

| **Port** | **Dir** | **Type / width** | **Producer** | **Consumer** | **Clock / reset** | **Handshake / idle** | **CDC/RDC** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| core_clk_i | input | logic / 1 | RTL-024.core_clk_o | RTL-023.core_clk_i | CORE_CLK / core_rst_n | free-running / N/A | same-domain |
| core_rst_n_i | input | logic / 1 | RTL-024.core_rst_n_o | RTL-023.core_rst_n_i | CORE_CLK / core_rst_n | asynchronous assert; synchronized release / 0 asserted | RDC-001 |
| module_reset_i | input | logic / 1 | RTL-002.module_reset_o[22] | RTL-023.module_reset_i | CORE_CLK / core_rst_n | synchronous local reset request / 0 | same-domain |
| control_i | input | dfc_rtl023_control_t / 34 | RTL-001.rtl023_control_o | RTL-023.control_i | CORE_CLK / core_rst_n | registered configuration and qualified commands / generated field resets | same-domain |
| status_o | output | dfc_rtl023_status_t / 75 | RTL-023.status_o | RTL-001.rtl023_status_i; RTL-002.module_ready_i[22]; RTL-002.module_fault_i[22] | CORE_CLK / core_rst_n | registered/coherent status; includes ready and local fault evidence / generated field resets; ready=0 | same-domain |
| timestamp_i | input | logic / 64 | RTL-004.timestamp_o | RTL-023.timestamp_i | CORE_CLK / core_rst_n | registered monotonic time / 0 | same-domain |
| evt_valid_o | output | logic / 1 | RTL-023.evt_valid_o | RTL-005.evt_valid_i[22] | CORE_CLK / core_rst_n | valid/ready; one pending slot / 0 | same-domain |
| evt_ready_i | input | logic / 1 | RTL-005.evt_ready_o[22] | RTL-023.evt_ready_i | CORE_CLK / core_rst_n | valid/ready / 0 | same-domain |
| evt_record_o | output | dfc_event_record_t / 128 | RTL-023.evt_record_o | RTL-005.evt_record_i[22] | CORE_CLK / core_rst_n | stable while valid and not ready / 0 | same-domain |
| irq_req_o | output | logic / 1 | RTL-023.irq_req_o | RTL-003.irq_source_i[19] | CORE_CLK / core_rst_n | level or sticky evidence as source matrix specifies / 0 | same-domain |
| fault_req_o | output | logic / 1 | RTL-023.fault_req_o | RTL-013.fault_source_i[16] | CORE_CLK / core_rst_n | active condition; RTL-013 latches evidence / 0 | same-domain |
| route_source_i | input | logic / 64 | dragon_core_top.internal_source_vector[63:0] | RTL-023.route_source_i[63:0] | CORE_CLK / core_rst_n | registered qualified values / 0 | same-domain |
| route_dest_o | output | logic / 32 | RTL-023.route_dest_o[31:0] | RTL-006.route_gpio_req_i[7:0]; RTL-022.route_user_req_i[3:0]; RTL-022.route_term_i[7:0]; RTL-023 internal event requests[1:0]; RTL-023 internal interrupt requests[1:0]; bit 0 no action; bits 25:31 inactive | CORE_CLK / core_rst_n | registered finite routes / 0 | same-domain |
| operating_state_i | input | dfc_operating_state_t / 3 | RTL-002.operating_state_o | RTL-023.operating_state_i | CORE_CLK / core_rst_n | registered operating-state broadcast / RESET_ACTIVE | same-domain |
| observational_mode_i | input | logic / 1 | RTL-002.observational_mode_o | RTL-023.observational_mode_i | CORE_CLK / core_rst_n | registered safety-mode broadcast / 1 | same-domain |
| module_enable_i | input | logic / 1 | RTL-002.module_enable_o[22] | RTL-023.module_enable_i | CORE_CLK / core_rst_n | registered optional-module enable; disabled module contributes no degraded/fault request / 0 | same-domain |
| effective_operational_enable_i | input | logic / 1 | RTL-002.effective_operational_enable_o | RTL-023.effective_operational_enable_i | CORE_CLK / core_rst_n | registered operational-action permission; low suppresses externally effective action / 0 | same-domain |
| event_condition_enable_i | input | logic / 64 | RTL-001.event_condition_enable_o[22] | RTL-023 event gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |
| irq_condition_enable_i | input | logic / 64 | RTL-001.irq_condition_enable_o[22] | RTL-023 interrupt gate | CORE_CLK / core_rst_n | registered mask; allocation in Appendix F.3 / 0 | same-domain |

### RTL-024 - Dragon Core Top-Level Integration (34 logical and platform ports)

RTL-024 has only wrapper/platform-facing ports. All RTL-001 through RTL-023 connections, generated core clock/reset nets, DRI, control/status, event, interrupt, fault, safety-request, canonical-message, and shared-buffer interfaces are internal nets owned by RTL-024 and are enumerated by ARCH-CONN-001 through ARCH-CONN-012.

| **Port** | **Dir** | **Type / width** | **External producer/consumer** | **Clock / reset** | **Safe/idle contract** | **CDC/RDC** |
|---|---|---|---|---|---|---|
| core_clk_i | input | logic / 1 | Platform clock source | Clock root / `por_n_i` | Nominal 50 MHz continuous | clock root |
| clock_fault_i | input | logic / 1 | Platform clock monitor | Asynchronous / `por_n_i` | Low when valid; asserted and held through four recovered CORE_CLK edges after invalid or lost clock | CDC-CLOCK |
| por_n_i | input | logic / 1 | Platform-wrapper POR | Asynchronous | Asserted low; internal wrapper input, not a pad | RDC-001; RDC-002; RDC-TEST-001 |
| spi_sclk_i | input | logic / 1 | External SPI master | SPI_SCLK / `spi_rst_n` | Mode 0, low idle | CDC-001; CDC-002 |
| spi_cs_n_i | input | logic / 1 | External SPI master | SPI_SCLK / `spi_rst_n` | High inactive | CDC-001; RDC-002 |
| spi_mosi_i | input | logic / 1 | External SPI master | SPI_SCLK / `spi_rst_n` | Ignored while CS_N high | CDC-001 |
| spi_miso_o | output | logic / 1 | External SPI master | SPI_SCLK / `spi_rst_n` | Zero when output enable is low | CDC-002 |
| spi_miso_oe_o | output | logic / 1 | SPI MISO pad output-enable | SPI_SCLK / `spi_rst_n` | Low while CS_N high and before response phase | CDC-002; RDC-002 |
| host_irq_n_o | output | logic / 1 | External host interrupt input | CORE_CLK / `core_rst_n` | High in reset or with no enabled pending source | external asynchronous output |
| gpio_i | input | logic / 8 | GPIO pad inputs | Asynchronous / `core_rst_n` | Sampled only through CDC-GPIO | CDC-GPIO |
| gpio_o | output | logic / 8 | GPIO pad data | CORE_CLK / `core_rst_n` | Zero in reset/disable/test | same-domain |
| gpio_oe_o | output | logic / 8 | GPIO pad output-enable | CORE_CLK / `core_rst_n` | Zero in reset/disable/test | same-domain |
| arinc_rx_i | input | logic / 1 | Conditioned ARINC receiver | Asynchronous / `core_rst_n` | Protocol recovered by adapter | CDC-ARINC |
| arinc_tx_ctrl_o | output | logic / 2 | External ARINC line driver | CORE_CLK / `core_rst_n` | `2'b00` idle | same-domain |
| arinc_rx_adapter_error_i | input | logic / 1 | External receive adapter | Asynchronous / `core_rst_n` | Active high | CDC-ARXERR |
| arinc_tx_adapter_error_i | input | logic / 1 | External transmit adapter | Asynchronous / `core_rst_n` | Active high | CDC-ATXERR |
| can_rx_i | input | logic / 1 | External CAN transceiver | Asynchronous / `core_rst_n` | Recessive high | CDC-CAN |
| can_tx_o | output | logic / 1 | External CAN transceiver | CORE_CLK / `core_rst_n` | Recessive high | same-domain |
| can_transceiver_error_i | input | logic / 1 | External CAN transceiver | Asynchronous / `core_rst_n` | Active high | CDC-CANERR |
| uart_rx_i | input | logic / 1 | External UART endpoint | Asynchronous / `core_rst_n` | Idle high | CDC-UART |
| uart_tx_o | output | logic / 1 | External UART endpoint | CORE_CLK / `core_rst_n` | Idle high | same-domain |
| rotor_i | input | logic / 1 | Conditioned rotor source | Asynchronous / `core_rst_n` | Sampled only through CDC-PULSE | CDC-PULSE |
| engine_i | input | logic / 1 | Conditioned engine source | Asynchronous / `core_rst_n` | Sampled only through CDC-PULSE | CDC-PULSE |
| pulse_i | input | logic / 2 | Conditioned pulse sources | Asynchronous / `core_rst_n` | Sampled only through CDC-PULSE | CDC-PULSE |
| health_i | input | logic / 8 | Conditioned health/discrete sources | Asynchronous / `core_rst_n` | Sampled only through CDC-HEALTH | CDC-HEALTH |
| safety_out_o | output | logic / 4 | External safety-driver logic inputs | CORE_CLK / `core_rst_n` | Inactive under every ARCH-SAFE inhibit | same-domain |
| user_i | input | logic / 4 | User pad inputs | Asynchronous / `core_rst_n` | Diagnostic capture only in Revision A | CDC-USER |
| user_o | output | logic / 4 | User pad data | CORE_CLK / `core_rst_n` | Constant zero in Revision A | same-domain |
| user_oe_o | output | logic / 4 | User pad output-enable | CORE_CLK / `core_rst_n` | Constant zero in Revision A | same-domain |
| test_enable_i | input | logic / 1 | External test fixture | Asynchronous / test/core resets | Low inactive | CDC-TEST-001; RDC-TEST-001 |
| test_clock_i | input | logic / 1 | External test fixture | TEST_CLK / `test_rst_n` | Ignored unless authorized | TEST_CLK root |
| test_data_i | input | logic / 1 | External test fixture | TEST_CLK / `test_rst_n` | Command input phase | CDC-TEST-001 |
| test_data_o | output | logic / 1 | External test fixture | TEST_CLK / `test_rst_n` | Shift result only | CDC-TEST-003 |
| test_data_oe_o | output | logic / 1 | TEST_DATA pad output-enable | TEST_CLK / `test_rst_n` | Asynchronously low on reset/deauthorization | CDC-TEST-003; RDC-TEST-001 |

# Appendix B — Shared Packed Types

The following packed layouts are the sole Architecture definitions of shared records and module control/status structures. Host-visible field semantics remain controlled by the Register Map.

### B.1 `dfc_event_record_t` — 128 bits

| **Absolute bits** | **Member** | **Width** |
| --- | --- | --- |
| 63:0 | timestamp | 64 |
| 79:64 | event_id | 16 |
| 87:80 | source_id | 8 |
| 95:88 | flags | 8 |
| 127:96 | event_data | 32 |

### B.2 `dfc_message_record_t` — 192 bits

| **Absolute bits** | **Member** | **Width** |
| --- | --- | --- |
| 191:128 | timestamp | 64 |
| 127:64 | payload | 64 |
| 63:32 | metadata | 32 |
| 31:24 | source_id | 8 |
| 23:16 | message_type | 8 |
| 15:12 | payload_length | 4 |
| 11:8 | sequence | 4 |
| 7:0 | flags | 8 |

### B.3 `dfc_buffer_req_t` — 42 bits

| **Bits** | **Member** | **Width** | **Contract** |
|---|---|---:|---|
| 8:0 | word_offset | 9 | Client-relative word offset; the service derives the absolute address |
| 9 | write | 1 | One for write, zero for read |
| 41:10 | write_data | 32 | Complete write word; ignored for read |

### B.4 `dfc_buffer_rsp_t` — 34 bits

| **Bits** | **Member** | **Width** | **Contract** |
|---|---|---:|---|
| 31:0 | read_data | 32 | Complete read word; zero for writes and errors |
| 33:32 | code | 2 | `00` OK, `01` RANGE_ERROR, `10` PROTOCOL_ERROR, `11` INTERNAL_ERROR |

### B.5 Module control and status structures

The following structures are exact packed interfaces between RTL-001 and the functional modules. Member meaning derives from the corresponding Architecture module contract and the Register Map field identified by the member name.

#### B.5.1 `dfc_rtl001_status_t` — 19 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | RTL-001 initialized and host register endpoint ready |
| 1 | fault | 1 | unsigned | 0 | RTL-001 local configuration/endpoint fault evidence |
| 2 | event_overflow | 1 | unsigned | 0 | RTL-001 event-source overflow evidence |
| 18:3 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |


### dfc_rtl002_control_t — 60 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | sys_control__operational_enable | 1 | unsigned | 0 | control_value |
| 1 | sys_control__observational_mode | 1 | unsigned | 1 | control_value |
| 2 | sys_control__global_irq_enable | 1 | unsigned | 0 | control_value |
| 3 | sys_control__global_event_enable | 1 | unsigned | 1 | control_value |
| 4 | sys_control__degraded_ack | 1 | unsigned | 0 | command_pulse |
| 28:5 | subsys_enable__enable | 24 | unsigned | 0x80F81F | control_value |
| 29 | reset_control__system_reset | 1 | unsigned | 0 | command_pulse |
| 53:30 | reset_control__module_reset | 24 | unsigned | 0 | command_pulse |
| 54 | reset_status__complete | 1 | unsigned | 0 | clear_mask |
| 55 | reset_status__rejected | 1 | unsigned | 0 | clear_mask |
| 56 | reset_control__safety_domain_reset | 1 | unsigned | 0 | command_pulse |
| 57 | reset_status__timeout | 1 | unsigned | 0 | W1C controlled-reset timeout evidence |
| 58 | reset_status__recovery_failure | 1 | unsigned | 0 | W1C failure to regain required ready state |
| 59 | rtl002_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask; host-initiated clear-request for RTL002_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-002 0x0044) -- added to close a real, confirmed operational gap: this struct previously had no field carrying this clear-request from RTL-001 into RTL-002, so the host had no way to acknowledge overflow evidence once set. Placed at the new highest bit specifically so every other field in this struct keeps its existing bit position unchanged. |

### dfc_rtl002_status_t — 112 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | sys_status__reset_active | 1 | unsigned | 1 | readback_value |
| 4 | sys_status__startup | 1 | unsigned | 0 | readback_value |
| 5 | sys_status__host_ready | 1 | unsigned | 0 | readback_value |
| 6 | sys_status__normal | 1 | unsigned | 0 | readback_value |
| 7 | sys_status__degraded | 1 | unsigned | 0 | readback_value |
| 8 | sys_status__faulted | 1 | unsigned | 0 | readback_value |
| 9 | sys_status__observational | 1 | unsigned | 1 | readback_value |
| 10 | sys_status__test_debug | 1 | unsigned | 0 | readback_value |
| 11 | sys_status__init_complete | 1 | unsigned | 0 | readback_value |
| 12 | sys_status__init_failed | 1 | unsigned | 0 | readback_value |
| 36:13 | subsys_ready__ready | 24 | unsigned | 0 | readback_value |
| 60:37 | subsys_fault__fault | 24 | unsigned | 0 | readback_value |
| 61 | reset_status__busy | 1 | unsigned | 0 | readback_value |
| 62 | reset_status__complete | 1 | unsigned | 0 | readback_value |
| 63 | reset_status__rejected | 1 | unsigned | 0 | readback_value |
| 87:64 | reset_status__last_scope | 24 | unsigned | 0 | readback_value |
| 92:88 | reset_status__last_result | 5 | unsigned | 0 | readback_value |
| 108:93 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 109 | sys_status__effective_operational_enable | 1 | unsigned | 0 | independent current-state readback; never inferred from commanded enable |
| 110 | reset_status__timeout | 1 | unsigned | 0 | sticky controlled-reset timeout evidence |
| 111 | reset_status__recovery_failure | 1 | unsigned | 0 | sticky failure to regain required ready state |

### dfc_rtl003_control_t — 129 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 31:0 | irq_enable__enable | 32 | unsigned | 0 | control_value |
| 63:32 | irq_ack__ack_set | 32 | unsigned | 0 | command_pulse |
| 95:64 | irq_clear__clear | 32 | unsigned | 0 | clear_mask |
| 127:96 | test_irq_inject__source_mask | 32 | unsigned | 0 | command_pulse |
| 128 | rtl003_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask; host-initiated clear-request for RTL003_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-002 0x011C, contract REG-011C) -- added to close a real, confirmed operational gap: this struct previously had no field carrying this clear-request from RTL-001 into RTL-003, so the host had no way to acknowledge overflow evidence once set. Placed at the new highest bit specifically so every other field in this struct keeps its existing bit position unchanged. |

### dfc_rtl003_status_t — 153 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 34:3 | irq_raw_status__raw_status | 32 | unsigned | 0 | readback_value |
| 66:35 | irq_pending__pending | 32 | unsigned | 0 | readback_value |
| 98:67 | irq_acked__acked | 32 | unsigned | 0 | readback_value |
| 130:99 | irq_clear__clear | 32 | unsigned | 0 | readback_value |
| 135:131 | irq_vector__source | 5 | unsigned | 0 | readback_value |
| 136 | irq_vector__valid | 1 | unsigned | 0 | readback_value |
| 152:137 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |

### dfc_rtl004_control_t — 73 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | time_control__enable | 1 | unsigned | 1 | constant_one; writes of zero rejected and reads remain one |
| 1 | time_control__correlation_enable | 1 | unsigned | 0 | control_value |
| 2 | time_status__sync_updated | 1 | unsigned | 0 | clear_mask |
| 3 | time_status__error | 1 | unsigned | 0 | clear_mask |
| 4 | time_snapshot__capture | 1 | unsigned | 0 | command_pulse |
| 36:5 | time_sync_offset_lo__offset_lo | 32 | unsigned | 0 | control_value |
| 68:37 | time_sync_offset_hi__offset_hi | 32 | unsigned | 0 | control_value |
| 69 | time_sync_commit__commit | 1 | unsigned | 0 | command_pulse |
| 70 | time_status__snapshot_valid | 1 | unsigned | 0 | clear_mask; host-initiated clear-request for TIME_STATUS.SNAPSHOT_VALID (REG-002 0x0204) -- added to close a real, confirmed operational gap: this struct previously had no field carrying this clear-request from RTL-001 into RTL-004, so the host had no way to acknowledge snapshot-valid evidence once set, despite REG-002 declaring the register bit real W1C. Placed at the new highest bit specifically so every other field in this struct keeps its existing bit position unchanged. |
| 71 | time_status__sync_valid | 1 | unsigned | 0 | clear_mask; host-initiated clear-request for TIME_STATUS.SYNC_VALID (REG-002 0x0204) -- same real, confirmed gap and same fix shape as bit 70 immediately above. Placed at the new highest bit specifically so every other field in this struct keeps its existing bit position unchanged. |
| 72 | rtl004_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask; host-initiated clear-request for RTL004_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-002 0x0224) -- same real, confirmed gap already fixed for RTL-002/RTL-003 (dfc_rtl002_control_t/dfc_rtl003_control_t), now closed for RTL-004 from the start rather than shipped with the gap. Placed at the new highest bit specifically so every other field in this struct keeps its existing bit position unchanged. |

### dfc_rtl004_status_t — 169 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | time_status__running | 1 | unsigned | 1 | readback_value |
| 4 | time_status__snapshot_valid | 1 | unsigned | 0 | readback_value |
| 5 | time_status__sync_valid | 1 | unsigned | 0 | readback_value |
| 6 | time_status__sync_updated | 1 | unsigned | 0 | readback_value |
| 7 | time_status__error | 1 | unsigned | 0 | readback_value |
| 39:8 | time_raw_lo__raw_lo | 32 | unsigned | 0 | readback_value |
| 71:40 | time_raw_hi__raw_hi | 32 | unsigned | 0 | readback_value |
| 87:72 | time_sync_status__update_sequence | 16 | unsigned | 0 | readback_value |
| 88 | time_sync_status__active_valid | 1 | unsigned | 0 | readback_value |
| 104:89 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 136:105 | time_active_offset_lo__offset_lo | 32 | unsigned | 0 | readback_value; added to close a real, confirmed gap: this struct previously had no field carrying the real active (committed) correlation offset back to TIME_ACTIVE_OFFSET_LO (REG-002 0x0228), an external-readback register with no other real data source. Placed at the new highest bits specifically so every other field in this struct keeps its existing bit position unchanged. |
| 168:137 | time_active_offset_hi__offset_hi | 32 | unsigned | 0 | readback_value; same real, confirmed gap and same fix shape as the field immediately above, for TIME_ACTIVE_OFFSET_HI (REG-002 0x022C). |

### dfc_rtl005_control_t — 129 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | evt_control__logger_enable | 1 | unsigned | 1 | control_value |
| 1 | evt_status__overflow | 1 | unsigned | 0 | clear_mask |
| 2 | evt_status__source_drop | 1 | unsigned | 0 | clear_mask |
| 3 | evt_status__pop_error | 1 | unsigned | 0 | clear_mask |
| 4 | evt_status__clear_complete | 1 | unsigned | 0 | clear_mask |
| 36:5 | evt_overflow_count__count | 32 | unsigned | 0 | clear_mask |
| 60:37 | evt_source_enable__source_enable | 24 | unsigned | 0xFFFFFF | control_value |
| 61 | evt_snapshot__capture_oldest | 1 | unsigned | 0 | command_pulse |
| 62 | evt_pop__pop | 1 | unsigned | 0 | command_pulse |
| 63 | evt_clear__clear_all | 1 | unsigned | 0 | command_pulse |
| 95:64 | evt_drop_source__source_drop | 32 | unsigned | 0 | clear_mask |
| 127:96 | evt_pop_error_count__count | 32 | unsigned | 0 | whole-counter clear for rejected empty POP operations |
| 128 | evt_status__snapshot_valid | 1 | unsigned | 0 | clear_mask; added to close a real, confirmed gap: this struct previously had no field for clearing EVT_STATUS.SNAPSHOT_VALID (REG-002 0x0304 bit 2, a real W1C field per REG-002's own text), identical in kind to the OVERFLOW/SOURCE_DROP/POP_ERROR/CLEAR_COMPLETE clear fields already present. Placed at the new highest bit specifically so every other field in this struct keeps its existing bit position unchanged. |

### dfc_rtl005_status_t — 268 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | evt_status__not_empty | 1 | unsigned | 0 | readback_value |
| 4 | evt_status__full | 1 | unsigned | 0 | readback_value |
| 5 | evt_status__snapshot_valid | 1 | unsigned | 0 | readback_value |
| 6 | evt_status__overflow | 1 | unsigned | 0 | readback_value |
| 7 | evt_status__source_drop | 1 | unsigned | 0 | readback_value |
| 8 | evt_status__pop_error | 1 | unsigned | 0 | readback_value |
| 9 | evt_status__clear_complete | 1 | unsigned | 0 | readback_value |
| 16:10 | evt_count__count | 7 | unsigned | 0 | readback_value |
| 48:17 | evt_overflow_count__count | 32 | unsigned | 0 | readback_value |
| 80:49 | evt_data0__timestamp_lo | 32 | unsigned | 0 | readback_value |
| 112:81 | evt_data1__timestamp_hi | 32 | unsigned | 0 | readback_value |
| 128:113 | evt_data2__event_id | 16 | unsigned | 0 | readback_value |
| 136:129 | evt_data2__source_id | 8 | unsigned | 0 | readback_value |
| 144:137 | evt_data2__flags | 8 | unsigned | 0 | readback_value |
| 176:145 | evt_data3__event_data | 32 | unsigned | 0 | readback_value |
| 208:177 | evt_drop_source__source_drop | 32 | unsigned | 0 | readback_value |
| 213:209 | evt_arb_status__last_source | 5 | unsigned | 0 | readback_value |
| 218:214 | evt_arb_status__next_source | 5 | unsigned | 0 | readback_value |
| 219 | evt_arb_status__arb_active | 1 | unsigned | 0 | readback_value |
| 235:220 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 267:236 | evt_pop_error_count__count | 32 | unsigned | 0 | saturating count of rejected empty POP operations |

### dfc_rtl006_control_t — 123 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | gpio_control__enable | 1 | unsigned | 0 | control_value |
| 1 | gpio_control__qualification_enable | 1 | unsigned | 0 | control_value |
| 9:2 | gpio_out__output | 8 | unsigned | 0 | control_value |
| 17:10 | gpio_rise_enable__rise_enable | 8 | unsigned | 0 | control_value |
| 25:18 | gpio_fall_enable__fall_enable | 8 | unsigned | 0 | control_value |
| 33:26 | gpio_event_enable__event_enable | 8 | unsigned | 0 | control_value |
| 41:34 | gpio_irq_enable__irq_enable | 8 | unsigned | 0 | control_value |
| 49:42 | gpio_event_status__event | 8 | unsigned | 0 | clear_mask |
| 57:50 | gpio_qual_0_3__ch0_ms | 8 | unsigned | 0 | control_value |
| 65:58 | gpio_qual_0_3__ch1_ms | 8 | unsigned | 0 | control_value |
| 73:66 | gpio_qual_0_3__ch2_ms | 8 | unsigned | 0 | control_value |
| 81:74 | gpio_qual_0_3__ch3_ms | 8 | unsigned | 0 | control_value |
| 89:82 | gpio_qual_4_7__ch4_ms | 8 | unsigned | 0 | control_value |
| 97:90 | gpio_qual_4_7__ch5_ms | 8 | unsigned | 0 | control_value |
| 105:98 | gpio_qual_4_7__ch6_ms | 8 | unsigned | 0 | control_value |
| 113:106 | gpio_qual_4_7__ch7_ms | 8 | unsigned | 0 | control_value |
| 121:114 | gpio_dir__direction | 8 | unsigned | 0 | RTL-006-owned direction configuration; one means output |
| 122 | rtl006_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask; added to close a real, confirmed gap: this struct previously had no field for clearing RTL006_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-002 0x0434 bit 0, a real W1C field), identical in kind to the analogous fix already made for dfc_rtl002/003/004/005_control_t. Placed at the new highest bit specifically so every other field in this struct keeps its existing bit position unchanged. |

### dfc_rtl006_status_t — 83 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 10:3 | gpio_raw_in__raw_input | 8 | unsigned | 0 | readback_value |
| 18:11 | gpio_sync_in__sync_input | 8 | unsigned | 0 | readback_value |
| 26:19 | gpio_qual_in__qual_input | 8 | unsigned | 0 | readback_value |
| 34:27 | gpio_event_status__event | 8 | unsigned | 0 | readback_value |
| 50:35 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 58:51 | gpio_status__commanded_output | 8 | unsigned | 0 | current pre-permit commanded output |
| 66:59 | gpio_status__effective_output | 8 | unsigned | 0 | current post-permit output data |
| 74:67 | gpio_status__direction | 8 | unsigned | 0 | active per-channel direction readback |
| 82:75 | gpio_status__qualification_in_progress | 8 | unsigned | 0 | current per-channel qualification-in-progress state |

### `dfc_rtl007_control_t` — 136 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | rotor_control__enable | 1 | unsigned | 0 | control_value |
| 1 | rotor_control__rising_edge | 1 | unsigned | 1 | control_value |
| 2 | rotor_control__event_enable | 1 | unsigned | 0 | control_value |
| 3 | rotor_control__irq_enable | 1 | unsigned | 0 | control_value |
| 4 | rotor_status__timeout | 1 | unsigned | 0 | clear_mask |
| 5 | rotor_status__range_error | 1 | unsigned | 0 | clear_mask |
| 6 | rotor_status__updated | 1 | unsigned | 0 | clear_mask |
| 22:7 | rotor_thresh_low__threshold | 16 | unsigned | 0 | control_value |
| 38:23 | rotor_thresh_high__threshold | 16 | unsigned | 1000 | control_value |
| 54:39 | rotor_pulses_per_rev__ppr | 16 | unsigned | 1 | control_value |
| 86:55 | rotor_timeout_us__timeout_us | 32 | unsigned | 100000 | control_value |
| 118:87 | rotor_edge_filter__min_edge_cycles | 32 | unsigned | 0 | control_value |
| 134:119 | rotor_hysteresis__hysteresis | 16 | unsigned | 0 | control_value |
| 135 | rtl007_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask; added to close a real, confirmed gap: this struct previously had no field for clearing RTL007_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-002 0x2024 bit 0, a real W1C field), identical in kind to the analogous fix already made for dfc_rtl002/003/004/005/006_control_t. Placed at the new highest bit specifically so every other field in this struct keeps its existing bit position unchanged. |

### dfc_rtl007_status_t — 73 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | rotor_status__valid | 1 | unsigned | 0 | readback_value |
| 4 | rotor_status__low | 1 | unsigned | 0 | readback_value |
| 5 | rotor_status__high | 1 | unsigned | 0 | readback_value |
| 6 | rotor_status__timeout | 1 | unsigned | 0 | readback_value |
| 7 | rotor_status__range_error | 1 | unsigned | 0 | readback_value |
| 8 | rotor_status__updated | 1 | unsigned | 0 | readback_value |
| 24:9 | rotor_rpm__rpm | 16 | unsigned | 0 | readback_value |
| 56:25 | rotor_period_ticks__period_ticks | 32 | unsigned | 0x00000000 | readback_value |
| 72:57 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |

### `dfc_rtl008_control_t` — 136 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | engine_control__enable | 1 | unsigned | 0 | control_value |
| 1 | engine_control__rising_edge | 1 | unsigned | 1 | control_value |
| 2 | engine_control__event_enable | 1 | unsigned | 0 | control_value |
| 3 | engine_control__irq_enable | 1 | unsigned | 0 | control_value |
| 4 | engine_status__timeout | 1 | unsigned | 0 | clear_mask |
| 5 | engine_status__range_error | 1 | unsigned | 0 | clear_mask |
| 6 | engine_status__updated | 1 | unsigned | 0 | clear_mask |
| 22:7 | engine_thresh_low__threshold | 16 | unsigned | 0 | control_value |
| 38:23 | engine_thresh_high__threshold | 16 | unsigned | 20000 | control_value |
| 54:39 | engine_pulses_per_rev__ppr | 16 | unsigned | 1 | control_value |
| 86:55 | engine_timeout_us__timeout_us | 32 | unsigned | 100000 | control_value |
| 118:87 | engine_edge_filter__min_edge_cycles | 32 | unsigned | 0 | control_value |
| 134:119 | engine_hysteresis__hysteresis | 16 | unsigned | 0 | control_value |
| 135 | rtl008_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask; added to close a real, confirmed gap: this struct previously had no field for clearing RTL008_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-002 0x2124 bit 0, a real W1C field), identical in kind to the analogous fix already made for dfc_rtl002/003/004/005/006/007_control_t. Placed at the new highest bit specifically so every other field in this struct keeps its existing bit position unchanged. |

### dfc_rtl008_status_t — 73 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | engine_status__valid | 1 | unsigned | 0 | readback_value |
| 4 | engine_status__low | 1 | unsigned | 0 | readback_value |
| 5 | engine_status__high | 1 | unsigned | 0 | readback_value |
| 6 | engine_status__timeout | 1 | unsigned | 0 | readback_value |
| 7 | engine_status__range_error | 1 | unsigned | 0 | readback_value |
| 8 | engine_status__updated | 1 | unsigned | 0 | readback_value |
| 24:9 | engine_rpm__rpm | 16 | unsigned | 0 | readback_value |
| 56:25 | engine_period_ticks__period_ticks | 32 | unsigned | 0x00000000 | readback_value |
| 72:57 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |

### `dfc_rtl009_control_t` — 335 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | pulse0_control__enable | 1 | unsigned | 0 | control_value |
| 1 | pulse0_control__rising_edge | 1 | unsigned | 1 | control_value |
| 2 | pulse0_control__event_enable | 1 | unsigned | 0 | control_value |
| 3 | pulse0_control__irq_enable | 1 | unsigned | 0 | control_value |
| 4 | pulse0_status__timeout | 1 | unsigned | 0 | clear_mask |
| 5 | pulse0_status__range_error | 1 | unsigned | 0 | clear_mask |
| 6 | pulse0_status__updated | 1 | unsigned | 0 | clear_mask |
| 38:7 | pulse0_thresh_low_q17_15__threshold | 32 | unsigned | 0x00004000 | control_value |
| 70:39 | pulse0_thresh_high_q17_15__threshold | 32 | unsigned | 0xC3500000 | control_value |
| 102:71 | pulse0_timeout_us__timeout_us | 32 | unsigned | 2500000 | control_value |
| 134:103 | pulse0_edge_filter__min_edge_cycles | 32 | unsigned | 0 | control_value |
| 135 | pulse1_control__enable | 1 | unsigned | 0 | control_value |
| 136 | pulse1_control__rising_edge | 1 | unsigned | 1 | control_value |
| 137 | pulse1_control__event_enable | 1 | unsigned | 0 | control_value |
| 138 | pulse1_control__irq_enable | 1 | unsigned | 0 | control_value |
| 139 | pulse1_status__timeout | 1 | unsigned | 0 | clear_mask |
| 140 | pulse1_status__range_error | 1 | unsigned | 0 | clear_mask |
| 141 | pulse1_status__updated | 1 | unsigned | 0 | clear_mask |
| 173:142 | pulse1_thresh_low_q17_15__threshold | 32 | unsigned | 0x00004000 | control_value |
| 205:174 | pulse1_thresh_high_q17_15__threshold | 32 | unsigned | 0xC3500000 | control_value |
| 237:206 | pulse1_timeout_us__timeout_us | 32 | unsigned | 2500000 | control_value |
| 269:238 | pulse1_edge_filter__min_edge_cycles | 32 | unsigned | 0 | control_value |
| 301:270 | pulse0_hysteresis_q17_15__hysteresis | 32 | unsigned | 0 | control_value |
| 333:302 | pulse1_hysteresis_q17_15__hysteresis | 32 | unsigned | 0 | control_value |
| 334 | rtl009_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |

### dfc_rtl009_status_t — 159 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | pulse0_status__valid | 1 | unsigned | 0 | readback_value |
| 4 | pulse0_status__low | 1 | unsigned | 0 | readback_value |
| 5 | pulse0_status__high | 1 | unsigned | 0 | readback_value |
| 6 | pulse0_status__timeout | 1 | unsigned | 0 | readback_value |
| 7 | pulse0_status__range_error | 1 | unsigned | 0 | readback_value |
| 8 | pulse0_status__updated | 1 | unsigned | 0 | readback_value |
| 40:9 | pulse0_freq_q17_15__frequency_q17_15 | 32 | unsigned | 0x00000000 | readback_value |
| 72:41 | pulse0_period_ticks__period_ticks | 32 | unsigned | 0x00000000 | readback_value |
| 73 | pulse1_status__valid | 1 | unsigned | 0 | readback_value |
| 74 | pulse1_status__low | 1 | unsigned | 0 | readback_value |
| 75 | pulse1_status__high | 1 | unsigned | 0 | readback_value |
| 76 | pulse1_status__timeout | 1 | unsigned | 0 | readback_value |
| 77 | pulse1_status__range_error | 1 | unsigned | 0 | readback_value |
| 78 | pulse1_status__updated | 1 | unsigned | 0 | readback_value |
| 110:79 | pulse1_freq_q17_15__frequency_q17_15 | 32 | unsigned | 0x00000000 | readback_value |
| 142:111 | pulse1_period_ticks__period_ticks | 32 | unsigned | 0x00000000 | readback_value |
| 158:143 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |

### `dfc_rtl010_control_t` — 346 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | sensor_control__enable | 1 | unsigned | 0 | control_value |
| 1 | sensor_control__event_enable | 1 | unsigned | 0 | control_value |
| 2 | sensor_control__irq_enable | 1 | unsigned | 0 | control_value |
| 3 | sensor_status__update_rejected | 1 | unsigned | 0 | clear_mask |
| 4 | sensor_status__updated | 1 | unsigned | 0 | clear_mask |
| 5 | sensor_update_select__channel | 1 | unsigned | 0 | control_value |
| 37:6 | sensor_update_value__value | 32 | signed | 0x00000000 | control_value |
| 38 | sensor_update_meta__valid | 1 | unsigned | 0 | control_value |
| 45:39 | sensor_update_meta__source | 7 | unsigned | 0 | control_value |
| 69:46 | sensor_update_meta__sequence | 24 | unsigned | 0 | control_value |
| 70 | sensor_update_commit__commit | 1 | unsigned | 0 | command_pulse |
| 71 | sensor0_status__event | 1 | unsigned | 0 | clear_mask |
| 103:72 | sensor0_max_age_ms__max_age_ms | 32 | unsigned | 0x00000000 | control_value |
| 135:104 | sensor0_thresh_low__threshold | 32 | signed | 0x80000000 | control_value |
| 167:136 | sensor0_thresh_high__threshold | 32 | signed | 0x7FFFFFFF | control_value |
| 171:168 | sensor0_event_irq_cfg__event_enable | 4 | unsigned | 0 | control_value |
| 175:172 | sensor0_event_irq_cfg__irq_enable | 4 | unsigned | 0 | control_value |
| 176 | sensor1_status__event | 1 | unsigned | 0 | clear_mask |
| 208:177 | sensor1_max_age_ms__max_age_ms | 32 | unsigned | 0x00000000 | control_value |
| 240:209 | sensor1_thresh_low__threshold | 32 | signed | 0x80000000 | control_value |
| 272:241 | sensor1_thresh_high__threshold | 32 | signed | 0x7FFFFFFF | control_value |
| 276:273 | sensor1_event_irq_cfg__event_enable | 4 | unsigned | 0 | control_value |
| 280:277 | sensor1_event_irq_cfg__irq_enable | 4 | unsigned | 0 | control_value |
| 312:281 | sensor0_hysteresis__hysteresis | 32 | signed | 0x00000000 | control_value |
| 344:313 | sensor1_hysteresis__hysteresis | 32 | signed | 0x00000000 | control_value |
| 345 | rtl010_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |

### `dfc_rtl010_status_t` — 225 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | sensor_status__any_invalid | 1 | unsigned | 0 | readback_value |
| 4 | sensor_status__any_stale | 1 | unsigned | 0 | readback_value |
| 5 | sensor_status__any_low | 1 | unsigned | 0 | readback_value |
| 6 | sensor_status__any_high | 1 | unsigned | 0 | readback_value |
| 7 | sensor_status__update_rejected | 1 | unsigned | 0 | readback_value |
| 8 | sensor_status__updated | 1 | unsigned | 0 | readback_value |
| 40:9 | sensor0_value__value | 32 | signed | 0x00000000 | readback_value |
| 41 | sensor0_status__valid | 1 | unsigned | 0 | readback_value |
| 42 | sensor0_status__stale | 1 | unsigned | 0 | readback_value |
| 43 | sensor0_status__low | 1 | unsigned | 0 | readback_value |
| 44 | sensor0_status__high | 1 | unsigned | 0 | readback_value |
| 45 | sensor0_status__event | 1 | unsigned | 0 | readback_value |
| 77:46 | sensor0_current_age_ms__current_age_ms | 32 | unsigned | 0x00000000 | readback_value |
| 109:78 | sensor1_value__value | 32 | signed | 0x00000000 | readback_value |
| 110 | sensor1_status__valid | 1 | unsigned | 0 | readback_value |
| 111 | sensor1_status__stale | 1 | unsigned | 0 | readback_value |
| 112 | sensor1_status__low | 1 | unsigned | 0 | readback_value |
| 113 | sensor1_status__high | 1 | unsigned | 0 | readback_value |
| 114 | sensor1_status__event | 1 | unsigned | 0 | readback_value |
| 146:115 | sensor1_current_age_ms__current_age_ms | 32 | unsigned | 0x00000000 | readback_value |
| 153:147 | sensor0_meta__source | 7 | unsigned | 0 | readback_value |
| 177:154 | sensor0_meta__sequence | 24 | unsigned | 0 | readback_value |
| 184:178 | sensor1_meta__source | 7 | unsigned | 0 | readback_value |
| 208:185 | sensor1_meta__sequence | 24 | unsigned | 0 | readback_value |
| 224:209 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |

### dfc_rtl011_control_t — 122 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | health_control__enable | 1 | unsigned | 0 | control_value |
| 8:1 | health_sticky__asserted | 8 | unsigned | 0 | clear_mask |
| 16:9 | health_sticky__recovered | 8 | unsigned | 0 | clear_mask |
| 24:17 | health_polarity__active_high | 8 | unsigned | 0 | control_value |
| 32:25 | health_fault_enable__fault_enable | 8 | unsigned | 0 | control_value |
| 40:33 | health_event_enable__event_enable | 8 | unsigned | 0 | control_value |
| 48:41 | health_irq_enable__irq_enable | 8 | unsigned | 0 | control_value |
| 56:49 | health_qual_0_3__ch0_ms | 8 | unsigned | 0 | control_value |
| 64:57 | health_qual_0_3__ch1_ms | 8 | unsigned | 0 | control_value |
| 72:65 | health_qual_0_3__ch2_ms | 8 | unsigned | 0 | control_value |
| 80:73 | health_qual_0_3__ch3_ms | 8 | unsigned | 0 | control_value |
| 88:81 | health_qual_4_7__ch4_ms | 8 | unsigned | 0 | control_value |
| 96:89 | health_qual_4_7__ch5_ms | 8 | unsigned | 0 | control_value |
| 104:97 | health_qual_4_7__ch6_ms | 8 | unsigned | 0 | control_value |
| 112:105 | health_qual_4_7__ch7_ms | 8 | unsigned | 0 | control_value |
| 120:113 | health_sticky__qualification_failure | 8 | unsigned | 0 | W1C mask for sticky per-channel qualification failure |
| 121 | rtl011_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask for RTL011_EVT_OVERFLOW_STATUS.EVENT_OVERFLOW (REG-2430 bit 0) |

### dfc_rtl011_status_t — 84 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 10:3 | health_raw_in__raw | 8 | unsigned | 0 | readback_value |
| 18:11 | health_sync_in__sync | 8 | unsigned | 0 | readback_value |
| 26:19 | health_qual_in__qualified | 8 | unsigned | 0 | readback_value |
| 34:27 | health_active__active | 8 | unsigned | 0 | readback_value |
| 42:35 | health_sticky__asserted | 8 | unsigned | 0 | readback_value |
| 50:43 | health_sticky__recovered | 8 | unsigned | 0 | readback_value |
| 66:51 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 74:67 | health_qualification__in_progress | 8 | unsigned | 0 | current per-channel qualification-in-progress state |
| 82:75 | health_sticky__qualification_failure | 8 | unsigned | 0 | sticky per-channel qualification-failure evidence |
| 83 | health_status__aggregate_fault | 1 | unsigned | 0 | current OR of active fault-enabled health channels |

### dfc_rtl012_control_t — 111 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | wdog_control__enable | 1 | unsigned | 0 | control_value |
| 1 | wdog_control__window_enable | 1 | unsigned | 0 | control_value |
| 2 | wdog_control__event_enable | 1 | unsigned | 0 | control_value |
| 3 | wdog_control__irq_enable | 1 | unsigned | 0 | control_value |
| 4 | wdog_control__fault_enable | 1 | unsigned | 0 | control_value |
| 8:5 | wdog_control__safety_response_mask | 4 | unsigned | 0 | control_value |
| 40:9 | wdog_window_open_us__window_open_us | 32 | unsigned | 0x00000000 | control_value |
| 72:41 | wdog_timeout_us__timeout_us | 32 | unsigned | 1000000 | control_value |
| 104:73 | wdog_service__service_key | 32 | unsigned | 0 | command_pulse |
| 105 | wdog_status__service_accepted | 1 | unsigned | 0 | clear_mask |
| 106 | wdog_status__early_service | 1 | unsigned | 0 | clear_mask |
| 107 | wdog_status__bad_service_key | 1 | unsigned | 0 | clear_mask |
| 108 | wdog_status__timeout | 1 | unsigned | 0 | clear_mask |
| 109 | wdog_recovery__recover | 1 | unsigned | 0 | command_pulse |
| 110 | rtl012_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |

### dfc_rtl012_status_t — 58 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | wdog_status__enabled | 1 | unsigned | 0 | readback_value |
| 4 | wdog_status__window_open | 1 | unsigned | 0 | readback_value |
| 5 | wdog_status__service_accepted | 1 | unsigned | 0 | readback_value |
| 6 | wdog_status__early_service | 1 | unsigned | 0 | readback_value |
| 7 | wdog_status__bad_service_key | 1 | unsigned | 0 | readback_value |
| 8 | wdog_status__timeout | 1 | unsigned | 0 | readback_value |
| 9 | wdog_status__response_pending | 1 | unsigned | 0 | readback_value |
| 41:10 | wdog_elapsed_us__elapsed_us | 32 | unsigned | 0x00000000 | readback_value |
| 57:42 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |

### dfc_rtl013_control_t — 113 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 31:0 | test_fault_inject__source_mask | 32 | unsigned | 0 | command_pulse |
| 32 | fault_control__enable | 1 | unsigned | 0 | control_value |
| 33 | fault_control__clear_all_req | 1 | unsigned | 0 | command_pulse |
| 34 | fault_status__fault_active | 1 | unsigned | 0 | clear_mask |
| 35 | fault_status__multi_fault | 1 | unsigned | 0 | clear_mask |
| 36 | fault_status__event_pending | 1 | unsigned | 0 | clear_mask |
| 37 | fault_status__response_pending | 1 | unsigned | 0 | clear_mask |
| 38 | fault_response__degraded_enable | 1 | unsigned | 0 | control_value |
| 39 | fault_response__safety_response_enable | 1 | unsigned | 0 | control_value |
| 40 | fault_response__event_on_clear | 1 | unsigned | 0 | control_value |
| 41 | fault_response__latch_until_host_clear | 1 | unsigned | 0 | control_value |
| 45:42 | fault_response__safety_output_request_enable | 4 | unsigned | 0 | control_value |
| 46 | degraded_status__entry | 1 | unsigned | 0 | clear_mask |
| 47 | degraded_status__recovered | 1 | unsigned | 0 | clear_mask |
| 79:48 | fault_latched_source__latched_source | 32 | unsigned | 0 | clear_mask |
| 111:80 | fault_recoverable_mask__recoverable | 32 | unsigned | 0x00017FEF | fixed Architecture constant; writes of any other value rejected |
| 112 | rtl013_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |

### dfc_rtl013_status_t — 106 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | fault_status__fault_active | 1 | unsigned | 0 | readback_value |
| 4 | fault_status__multi_fault | 1 | unsigned | 0 | readback_value |
| 5 | fault_status__event_pending | 1 | unsigned | 0 | readback_value |
| 6 | fault_status__response_pending | 1 | unsigned | 0 | readback_value |
| 7 | fault_status__class_valid | 1 | unsigned | 0 | readback_value |
| 15:8 | fault_class__class | 8 | unsigned | 0 | readback_value |
| 20:16 | fault_class__primary_source | 5 | unsigned | 0 | readback_value |
| 21 | fault_class__multiple | 1 | unsigned | 0 | readback_value |
| 22 | degraded_status__active | 1 | unsigned | 0 | readback_value |
| 23 | degraded_status__entry | 1 | unsigned | 0 | readback_value |
| 24 | degraded_status__recovery_available | 1 | unsigned | 0 | readback_value |
| 25 | degraded_status__recovered | 1 | unsigned | 0 | readback_value |
| 57:26 | fault_active_source__active_source | 32 | unsigned | 0 | readback_value |
| 89:58 | fault_latched_source__latched_source | 32 | unsigned | 0 | readback_value |
| 105:90 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |

### dfc_rtl014_control_t — 513 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ilock_control__enable | 1 | unsigned | 0 | control_value |
| 1 | ilock_control__event_enable | 1 | unsigned | 0 | control_value |
| 2 | ilock_control__irq_enable | 1 | unsigned | 0 | control_value |
| 10:3 | ilock_status__violation_sticky | 8 | unsigned | 0 | clear_mask |
| 11 | ilock_status__commit_complete | 1 | unsigned | 0 | clear_mask |
| 12 | ilock_status__commit_rejected | 1 | unsigned | 0 | clear_mask |
| 15:13 | ilock_entry_select__entry | 3 | unsigned | 0 | control_value |
| 23:16 | ilock_stage_terms__term0 | 8 | unsigned | 0 | control_value |
| 31:24 | ilock_stage_terms__term1 | 8 | unsigned | 0 | control_value |
| 39:32 | ilock_stage_terms__term2 | 8 | unsigned | 0 | control_value |
| 47:40 | ilock_stage_terms__term3 | 8 | unsigned | 0 | control_value |
| 51:48 | ilock_stage_logic__invert_mask | 4 | unsigned | 0 | control_value |
| 54:52 | ilock_stage_logic__operator | 3 | unsigned | 0 | control_value |
| 62:55 | ilock_stage_guard__guard_mask | 8 | unsigned | 0 | control_value |
| 63 | ilock_stage_enable__enable | 1 | unsigned | 0 | control_value |
| 64 | ilock_stage_enable__latch_violation | 1 | unsigned | 0 | control_value |
| 65 | ilock_stage_enable__event_enable | 1 | unsigned | 0 | control_value |
| 66 | ilock_stage_enable__irq_enable | 1 | unsigned | 0 | control_value |
| 67 | ilock_validate_commit__commit_all | 1 | unsigned | 0 | command_pulse |
| 71:68 | ilock_stage_response__safety_response_mask | 4 | unsigned | 0 | control_value |
| 72 | rtl014_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |
| 80:73 | ilock_stage_e0__term0 | 8 | unsigned | 0 | control_value |
| 88:81 | ilock_stage_e0__term1 | 8 | unsigned | 0 | control_value |
| 96:89 | ilock_stage_e0__term2 | 8 | unsigned | 0 | control_value |
| 104:97 | ilock_stage_e0__term3 | 8 | unsigned | 0 | control_value |
| 108:105 | ilock_stage_e0__invert_mask | 4 | unsigned | 0 | control_value |
| 111:109 | ilock_stage_e0__operator | 3 | unsigned | 0 | control_value |
| 119:112 | ilock_stage_e0__guard_mask | 8 | unsigned | 0 | control_value |
| 120 | ilock_stage_e0__enable | 1 | unsigned | 0 | control_value |
| 121 | ilock_stage_e0__latch_violation | 1 | unsigned | 0 | control_value |
| 122 | ilock_stage_e0__event_enable | 1 | unsigned | 0 | control_value |
| 123 | ilock_stage_e0__irq_enable | 1 | unsigned | 0 | control_value |
| 127:124 | ilock_stage_e0__safety_response_mask | 4 | unsigned | 0 | control_value |
| 135:128 | ilock_stage_e1__term0 | 8 | unsigned | 0 | control_value |
| 143:136 | ilock_stage_e1__term1 | 8 | unsigned | 0 | control_value |
| 151:144 | ilock_stage_e1__term2 | 8 | unsigned | 0 | control_value |
| 159:152 | ilock_stage_e1__term3 | 8 | unsigned | 0 | control_value |
| 163:160 | ilock_stage_e1__invert_mask | 4 | unsigned | 0 | control_value |
| 166:164 | ilock_stage_e1__operator | 3 | unsigned | 0 | control_value |
| 174:167 | ilock_stage_e1__guard_mask | 8 | unsigned | 0 | control_value |
| 175 | ilock_stage_e1__enable | 1 | unsigned | 0 | control_value |
| 176 | ilock_stage_e1__latch_violation | 1 | unsigned | 0 | control_value |
| 177 | ilock_stage_e1__event_enable | 1 | unsigned | 0 | control_value |
| 178 | ilock_stage_e1__irq_enable | 1 | unsigned | 0 | control_value |
| 182:179 | ilock_stage_e1__safety_response_mask | 4 | unsigned | 0 | control_value |
| 190:183 | ilock_stage_e2__term0 | 8 | unsigned | 0 | control_value |
| 198:191 | ilock_stage_e2__term1 | 8 | unsigned | 0 | control_value |
| 206:199 | ilock_stage_e2__term2 | 8 | unsigned | 0 | control_value |
| 214:207 | ilock_stage_e2__term3 | 8 | unsigned | 0 | control_value |
| 218:215 | ilock_stage_e2__invert_mask | 4 | unsigned | 0 | control_value |
| 221:219 | ilock_stage_e2__operator | 3 | unsigned | 0 | control_value |
| 229:222 | ilock_stage_e2__guard_mask | 8 | unsigned | 0 | control_value |
| 230 | ilock_stage_e2__enable | 1 | unsigned | 0 | control_value |
| 231 | ilock_stage_e2__latch_violation | 1 | unsigned | 0 | control_value |
| 232 | ilock_stage_e2__event_enable | 1 | unsigned | 0 | control_value |
| 233 | ilock_stage_e2__irq_enable | 1 | unsigned | 0 | control_value |
| 237:234 | ilock_stage_e2__safety_response_mask | 4 | unsigned | 0 | control_value |
| 245:238 | ilock_stage_e3__term0 | 8 | unsigned | 0 | control_value |
| 253:246 | ilock_stage_e3__term1 | 8 | unsigned | 0 | control_value |
| 261:254 | ilock_stage_e3__term2 | 8 | unsigned | 0 | control_value |
| 269:262 | ilock_stage_e3__term3 | 8 | unsigned | 0 | control_value |
| 273:270 | ilock_stage_e3__invert_mask | 4 | unsigned | 0 | control_value |
| 276:274 | ilock_stage_e3__operator | 3 | unsigned | 0 | control_value |
| 284:277 | ilock_stage_e3__guard_mask | 8 | unsigned | 0 | control_value |
| 285 | ilock_stage_e3__enable | 1 | unsigned | 0 | control_value |
| 286 | ilock_stage_e3__latch_violation | 1 | unsigned | 0 | control_value |
| 287 | ilock_stage_e3__event_enable | 1 | unsigned | 0 | control_value |
| 288 | ilock_stage_e3__irq_enable | 1 | unsigned | 0 | control_value |
| 292:289 | ilock_stage_e3__safety_response_mask | 4 | unsigned | 0 | control_value |
| 300:293 | ilock_stage_e4__term0 | 8 | unsigned | 0 | control_value |
| 308:301 | ilock_stage_e4__term1 | 8 | unsigned | 0 | control_value |
| 316:309 | ilock_stage_e4__term2 | 8 | unsigned | 0 | control_value |
| 324:317 | ilock_stage_e4__term3 | 8 | unsigned | 0 | control_value |
| 328:325 | ilock_stage_e4__invert_mask | 4 | unsigned | 0 | control_value |
| 331:329 | ilock_stage_e4__operator | 3 | unsigned | 0 | control_value |
| 339:332 | ilock_stage_e4__guard_mask | 8 | unsigned | 0 | control_value |
| 340 | ilock_stage_e4__enable | 1 | unsigned | 0 | control_value |
| 341 | ilock_stage_e4__latch_violation | 1 | unsigned | 0 | control_value |
| 342 | ilock_stage_e4__event_enable | 1 | unsigned | 0 | control_value |
| 343 | ilock_stage_e4__irq_enable | 1 | unsigned | 0 | control_value |
| 347:344 | ilock_stage_e4__safety_response_mask | 4 | unsigned | 0 | control_value |
| 355:348 | ilock_stage_e5__term0 | 8 | unsigned | 0 | control_value |
| 363:356 | ilock_stage_e5__term1 | 8 | unsigned | 0 | control_value |
| 371:364 | ilock_stage_e5__term2 | 8 | unsigned | 0 | control_value |
| 379:372 | ilock_stage_e5__term3 | 8 | unsigned | 0 | control_value |
| 383:380 | ilock_stage_e5__invert_mask | 4 | unsigned | 0 | control_value |
| 386:384 | ilock_stage_e5__operator | 3 | unsigned | 0 | control_value |
| 394:387 | ilock_stage_e5__guard_mask | 8 | unsigned | 0 | control_value |
| 395 | ilock_stage_e5__enable | 1 | unsigned | 0 | control_value |
| 396 | ilock_stage_e5__latch_violation | 1 | unsigned | 0 | control_value |
| 397 | ilock_stage_e5__event_enable | 1 | unsigned | 0 | control_value |
| 398 | ilock_stage_e5__irq_enable | 1 | unsigned | 0 | control_value |
| 402:399 | ilock_stage_e5__safety_response_mask | 4 | unsigned | 0 | control_value |
| 410:403 | ilock_stage_e6__term0 | 8 | unsigned | 0 | control_value |
| 418:411 | ilock_stage_e6__term1 | 8 | unsigned | 0 | control_value |
| 426:419 | ilock_stage_e6__term2 | 8 | unsigned | 0 | control_value |
| 434:427 | ilock_stage_e6__term3 | 8 | unsigned | 0 | control_value |
| 438:435 | ilock_stage_e6__invert_mask | 4 | unsigned | 0 | control_value |
| 441:439 | ilock_stage_e6__operator | 3 | unsigned | 0 | control_value |
| 449:442 | ilock_stage_e6__guard_mask | 8 | unsigned | 0 | control_value |
| 450 | ilock_stage_e6__enable | 1 | unsigned | 0 | control_value |
| 451 | ilock_stage_e6__latch_violation | 1 | unsigned | 0 | control_value |
| 452 | ilock_stage_e6__event_enable | 1 | unsigned | 0 | control_value |
| 453 | ilock_stage_e6__irq_enable | 1 | unsigned | 0 | control_value |
| 457:454 | ilock_stage_e6__safety_response_mask | 4 | unsigned | 0 | control_value |
| 465:458 | ilock_stage_e7__term0 | 8 | unsigned | 0 | control_value |
| 473:466 | ilock_stage_e7__term1 | 8 | unsigned | 0 | control_value |
| 481:474 | ilock_stage_e7__term2 | 8 | unsigned | 0 | control_value |
| 489:482 | ilock_stage_e7__term3 | 8 | unsigned | 0 | control_value |
| 493:490 | ilock_stage_e7__invert_mask | 4 | unsigned | 0 | control_value |
| 496:494 | ilock_stage_e7__operator | 3 | unsigned | 0 | control_value |
| 504:497 | ilock_stage_e7__guard_mask | 8 | unsigned | 0 | control_value |
| 505 | ilock_stage_e7__enable | 1 | unsigned | 0 | control_value |
| 506 | ilock_stage_e7__latch_violation | 1 | unsigned | 0 | control_value |
| 507 | ilock_stage_e7__event_enable | 1 | unsigned | 0 | control_value |
| 508 | ilock_stage_e7__irq_enable | 1 | unsigned | 0 | control_value |
| 512:509 | ilock_stage_e7__safety_response_mask | 4 | unsigned | 0 | control_value |

### dfc_rtl014_status_t — 115 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 10:3 | ilock_status__violation_active | 8 | unsigned | 0 | readback_value |
| 18:11 | ilock_status__violation_sticky | 8 | unsigned | 0 | readback_value |
| 19 | ilock_status__commit_complete | 1 | unsigned | 0 | readback_value |
| 20 | ilock_status__commit_rejected | 1 | unsigned | 0 | readback_value |
| 28:21 | ilock_active_result__entry_true | 8 | unsigned | 0 | readback_value |
| 36:29 | ilock_active_result__guard_allowed | 8 | unsigned | 0 | readback_value |
| 52:37 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 60:53 | ilock_active_terms__term0 | 8 | unsigned | 0 | readback_value |
| 68:61 | ilock_active_terms__term1 | 8 | unsigned | 0 | readback_value |
| 76:69 | ilock_active_terms__term2 | 8 | unsigned | 0 | readback_value |
| 84:77 | ilock_active_terms__term3 | 8 | unsigned | 0 | readback_value |
| 88:85 | ilock_active_logic__invert_mask | 4 | unsigned | 0 | readback_value |
| 91:89 | ilock_active_logic__operator | 3 | unsigned | 0 | readback_value |
| 99:92 | ilock_active_guard__guard_mask | 8 | unsigned | 0 | readback_value |
| 100 | ilock_active_enable__enable | 1 | unsigned | 0 | readback_value |
| 101 | ilock_active_enable__latch_violation | 1 | unsigned | 0 | readback_value |
| 102 | ilock_active_enable__event_enable | 1 | unsigned | 0 | readback_value |
| 103 | ilock_active_enable__irq_enable | 1 | unsigned | 0 | readback_value |
| 107:104 | ilock_active_response__safety_response_mask | 4 | unsigned | 0 | readback_value |
| 110:108 | ilock_status__first_error_entry | 3 | unsigned | 0 | readback_value |
| 114:111 | ilock_status__first_error_code | 4 | unsigned | 0 | readback_value |

### dfc_rtl015_control_t — 961 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | llink_control__enable | 1 | unsigned | 0 | control_value |
| 1 | llink_control__event_enable | 1 | unsigned | 0 | control_value |
| 2 | llink_control__irq_enable | 1 | unsigned | 0 | control_value |
| 10:3 | llink_status__lost_sticky | 8 | unsigned | 0 | clear_mask |
| 18:11 | llink_status__recovered | 8 | unsigned | 0 | clear_mask |
| 21:19 | llink_monitor_select__monitor | 3 | unsigned | 0 | control_value |
| 22 | llink_monitor_control__enable | 1 | unsigned | 0 | control_value |
| 23 | llink_monitor_control__event_enable | 1 | unsigned | 0 | control_value |
| 24 | llink_monitor_control__irq_enable | 1 | unsigned | 0 | control_value |
| 25 | llink_monitor_control__fault_enable | 1 | unsigned | 0 | control_value |
| 29:26 | llink_monitor_control__safety_response_mask | 4 | unsigned | 0 | control_value |
| 61:30 | llink_qualify_us__qualify_us | 32 | unsigned | 0x00000000 | control_value |
| 93:62 | llink_timeout_us__timeout_us | 32 | unsigned | 1000000 | control_value |
| 125:94 | llink_recovery_us__recovery_us | 32 | unsigned | 100000 | control_value |
| 127:126 | llink_activity_inject__heartbeat | 2 | unsigned | 0 | command_pulse |
| 128 | rtl015_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |
| 129 | llink_monitor_m0__enable | 1 | unsigned | 0 | control_value |
| 130 | llink_monitor_m0__event_enable | 1 | unsigned | 0 | control_value |
| 131 | llink_monitor_m0__irq_enable | 1 | unsigned | 0 | control_value |
| 132 | llink_monitor_m0__fault_enable | 1 | unsigned | 0 | control_value |
| 136:133 | llink_monitor_m0__safety_response_mask | 4 | unsigned | 0 | control_value |
| 168:137 | llink_monitor_m0__qualify_us | 32 | unsigned | 0 | control_value |
| 200:169 | llink_monitor_m0__timeout_us | 32 | unsigned | 0 | control_value |
| 232:201 | llink_monitor_m0__recovery_us | 32 | unsigned | 0 | control_value |
| 233 | llink_monitor_m1__enable | 1 | unsigned | 0 | control_value |
| 234 | llink_monitor_m1__event_enable | 1 | unsigned | 0 | control_value |
| 235 | llink_monitor_m1__irq_enable | 1 | unsigned | 0 | control_value |
| 236 | llink_monitor_m1__fault_enable | 1 | unsigned | 0 | control_value |
| 240:237 | llink_monitor_m1__safety_response_mask | 4 | unsigned | 0 | control_value |
| 272:241 | llink_monitor_m1__qualify_us | 32 | unsigned | 0 | control_value |
| 304:273 | llink_monitor_m1__timeout_us | 32 | unsigned | 0 | control_value |
| 336:305 | llink_monitor_m1__recovery_us | 32 | unsigned | 0 | control_value |
| 337 | llink_monitor_m2__enable | 1 | unsigned | 0 | control_value |
| 338 | llink_monitor_m2__event_enable | 1 | unsigned | 0 | control_value |
| 339 | llink_monitor_m2__irq_enable | 1 | unsigned | 0 | control_value |
| 340 | llink_monitor_m2__fault_enable | 1 | unsigned | 0 | control_value |
| 344:341 | llink_monitor_m2__safety_response_mask | 4 | unsigned | 0 | control_value |
| 376:345 | llink_monitor_m2__qualify_us | 32 | unsigned | 0 | control_value |
| 408:377 | llink_monitor_m2__timeout_us | 32 | unsigned | 0 | control_value |
| 440:409 | llink_monitor_m2__recovery_us | 32 | unsigned | 0 | control_value |
| 441 | llink_monitor_m3__enable | 1 | unsigned | 0 | control_value |
| 442 | llink_monitor_m3__event_enable | 1 | unsigned | 0 | control_value |
| 443 | llink_monitor_m3__irq_enable | 1 | unsigned | 0 | control_value |
| 444 | llink_monitor_m3__fault_enable | 1 | unsigned | 0 | control_value |
| 448:445 | llink_monitor_m3__safety_response_mask | 4 | unsigned | 0 | control_value |
| 480:449 | llink_monitor_m3__qualify_us | 32 | unsigned | 0 | control_value |
| 512:481 | llink_monitor_m3__timeout_us | 32 | unsigned | 0 | control_value |
| 544:513 | llink_monitor_m3__recovery_us | 32 | unsigned | 0 | control_value |
| 545 | llink_monitor_m4__enable | 1 | unsigned | 0 | control_value |
| 546 | llink_monitor_m4__event_enable | 1 | unsigned | 0 | control_value |
| 547 | llink_monitor_m4__irq_enable | 1 | unsigned | 0 | control_value |
| 548 | llink_monitor_m4__fault_enable | 1 | unsigned | 0 | control_value |
| 552:549 | llink_monitor_m4__safety_response_mask | 4 | unsigned | 0 | control_value |
| 584:553 | llink_monitor_m4__qualify_us | 32 | unsigned | 0 | control_value |
| 616:585 | llink_monitor_m4__timeout_us | 32 | unsigned | 0 | control_value |
| 648:617 | llink_monitor_m4__recovery_us | 32 | unsigned | 0 | control_value |
| 649 | llink_monitor_m5__enable | 1 | unsigned | 0 | control_value |
| 650 | llink_monitor_m5__event_enable | 1 | unsigned | 0 | control_value |
| 651 | llink_monitor_m5__irq_enable | 1 | unsigned | 0 | control_value |
| 652 | llink_monitor_m5__fault_enable | 1 | unsigned | 0 | control_value |
| 656:653 | llink_monitor_m5__safety_response_mask | 4 | unsigned | 0 | control_value |
| 688:657 | llink_monitor_m5__qualify_us | 32 | unsigned | 0 | control_value |
| 720:689 | llink_monitor_m5__timeout_us | 32 | unsigned | 0 | control_value |
| 752:721 | llink_monitor_m5__recovery_us | 32 | unsigned | 0 | control_value |
| 753 | llink_monitor_m6__enable | 1 | unsigned | 0 | control_value |
| 754 | llink_monitor_m6__event_enable | 1 | unsigned | 0 | control_value |
| 755 | llink_monitor_m6__irq_enable | 1 | unsigned | 0 | control_value |
| 756 | llink_monitor_m6__fault_enable | 1 | unsigned | 0 | control_value |
| 760:757 | llink_monitor_m6__safety_response_mask | 4 | unsigned | 0 | control_value |
| 792:761 | llink_monitor_m6__qualify_us | 32 | unsigned | 0 | control_value |
| 824:793 | llink_monitor_m6__timeout_us | 32 | unsigned | 0 | control_value |
| 856:825 | llink_monitor_m6__recovery_us | 32 | unsigned | 0 | control_value |
| 857 | llink_monitor_m7__enable | 1 | unsigned | 0 | control_value |
| 858 | llink_monitor_m7__event_enable | 1 | unsigned | 0 | control_value |
| 859 | llink_monitor_m7__irq_enable | 1 | unsigned | 0 | control_value |
| 860 | llink_monitor_m7__fault_enable | 1 | unsigned | 0 | control_value |
| 864:861 | llink_monitor_m7__safety_response_mask | 4 | unsigned | 0 | control_value |
| 896:865 | llink_monitor_m7__qualify_us | 32 | unsigned | 0 | control_value |
| 928:897 | llink_monitor_m7__timeout_us | 32 | unsigned | 0 | control_value |
| 960:929 | llink_monitor_m7__recovery_us | 32 | unsigned | 0 | control_value |

### dfc_rtl015_status_t — 75 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 10:3 | llink_status__lost_active | 8 | unsigned | 0 | readback_value |
| 18:11 | llink_status__lost_sticky | 8 | unsigned | 0 | readback_value |
| 26:19 | llink_status__recovered | 8 | unsigned | 0 | readback_value |
| 58:27 | llink_elapsed_us__elapsed_us | 32 | unsigned | 0x00000000 | readback_value |
| 74:59 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |

### `dfc_rtl016_control_t` — 226 bits

All four logical safety-output channels run simultaneously and
continuously (each independently evaluates its own `PERMIT[c]` every
cycle per SS10.4), so a single selected-only view of
`SAFETY_CHANNEL_CONTROL`/`SAFETY_RESPONSE_MASK`/`SAFETY_INTERLOCK_MASK`
cannot carry the live configuration of all four — the same architectural
problem `dfc_rtl014_control_t` (item 68) and `dfc_rtl015_control_t`
(item 82) already solved. The struct keeps the pre-existing
selected-channel view (bits 9-11, 12-43, 44-51, forwarded but
functionally unused by `dfc_rtl016.sv` per the item 73 precedent) and
adds a complete 4-channel array (`safety_channel_c<0..3>__*`, 43 bits
each) below, reusing `reggen.py` v5's `indexed_registers` mechanism
unchanged (`OPEN_ISSUES.md` item 90).

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | safety_control__enable | 1 | unsigned | 0 | control_value |
| 1 | safety_control__event_enable | 1 | unsigned | 0 | control_value |
| 2 | safety_control__irq_enable | 1 | unsigned | 0 | control_value |
| 6:3 | safety_status__event | 4 | unsigned | 0 | clear_mask |
| 8:7 | safety_channel_select__channel | 2 | unsigned | 0 | control_value |
| 9 | safety_channel_control__enable | 1 | unsigned | 0 | control_value |
| 10 | safety_channel_control__latch_response | 1 | unsigned | 0 | control_value |
| 11 | safety_channel_control__active_high | 1 | unsigned | 1 | control_value |
| 43:12 | safety_response_mask__response_source_mask | 32 | unsigned | 0 | control_value |
| 51:44 | safety_interlock_mask__required_interlocks | 8 | unsigned | 0 | control_value |
| 52 | safety_control__global_inhibit | 1 | unsigned | 1 | explicit global inhibit; independent of controller enable |
| 53 | safety_channel_c0__enable | 1 | unsigned | 0 | control_value |
| 54 | safety_channel_c0__latch_response | 1 | unsigned | 0 | control_value |
| 55 | safety_channel_c0__active_high | 1 | unsigned | 1 | control_value |
| 87:56 | safety_channel_c0__response_source_mask | 32 | unsigned | 0 | control_value |
| 95:88 | safety_channel_c0__required_interlocks | 8 | unsigned | 0 | control_value |
| 96 | safety_channel_c1__enable | 1 | unsigned | 0 | control_value |
| 97 | safety_channel_c1__latch_response | 1 | unsigned | 0 | control_value |
| 98 | safety_channel_c1__active_high | 1 | unsigned | 1 | control_value |
| 130:99 | safety_channel_c1__response_source_mask | 32 | unsigned | 0 | control_value |
| 138:131 | safety_channel_c1__required_interlocks | 8 | unsigned | 0 | control_value |
| 139 | safety_channel_c2__enable | 1 | unsigned | 0 | control_value |
| 140 | safety_channel_c2__latch_response | 1 | unsigned | 0 | control_value |
| 141 | safety_channel_c2__active_high | 1 | unsigned | 1 | control_value |
| 173:142 | safety_channel_c2__response_source_mask | 32 | unsigned | 0 | control_value |
| 181:174 | safety_channel_c2__required_interlocks | 8 | unsigned | 0 | control_value |
| 182 | safety_channel_c3__enable | 1 | unsigned | 0 | control_value |
| 183 | safety_channel_c3__latch_response | 1 | unsigned | 0 | control_value |
| 184 | safety_channel_c3__active_high | 1 | unsigned | 1 | control_value |
| 216:185 | safety_channel_c3__response_source_mask | 32 | unsigned | 0 | control_value |
| 224:217 | safety_channel_c3__required_interlocks | 8 | unsigned | 0 | control_value |
| 225 | rtl016_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |

### dfc_rtl016_status_t — 52 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 6:3 | safety_status__commanded | 4 | unsigned | 0 | readback_value |
| 10:7 | safety_status__effective | 4 | unsigned | 0 | readback_value |
| 14:11 | safety_status__inhibited | 4 | unsigned | 0 | readback_value |
| 18:15 | safety_status__faulted | 4 | unsigned | 0 | readback_value |
| 22:19 | safety_status__event | 4 | unsigned | 0 | readback_value |
| 23 | safety_channel_status__command_request | 1 | unsigned | 0 | current requested state before latch policy |
| 24 | safety_channel_status__effective_output | 1 | unsigned | 0 | readback_value |
| 25 | safety_channel_status__disabled | 1 | unsigned | 1 | readback_value |
| 26 | safety_channel_status__observational_inhibit | 1 | unsigned | 1 | readback_value |
| 27 | safety_channel_status__interlock_inhibit | 1 | unsigned | 0 | readback_value |
| 28 | safety_channel_status__fault_inhibit | 1 | unsigned | 0 | readback_value |
| 29 | safety_channel_status__reset_active | 1 | unsigned | 1 | readback_value |
| 30 | safety_channel_status__test_inhibit | 1 | unsigned | 1 | readback_value |
| 46:31 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 47 | safety_channel_status__latched_request | 1 | unsigned | 0 | retained request state for selected channel |
| 48 | safety_channel_status__commanded | 1 | unsigned | 0 | current requested OR latched-request state |
| 49 | safety_channel_status__controller_disabled | 1 | unsigned | 1 | current controller-disabled cause |
| 50 | safety_channel_status__global_inhibit | 1 | unsigned | 1 | current explicit global-inhibit cause |
| 51 | safety_channel_status__operational_inhibit | 1 | unsigned | 1 | current effective-operational-enable inhibit cause |

### dfc_rtl017_control_t — 105 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | arx_status__parity_error | 1 | unsigned | 0 | clear_mask |
| 1 | arx_status__framing_error | 1 | unsigned | 0 | clear_mask |
| 2 | arx_status__overrun | 1 | unsigned | 0 | clear_mask |
| 3 | arx_status__adapter_error | 1 | unsigned | 0 | clear_mask |
| 4 | arx_snapshot__capture | 1 | unsigned | 0 | command_pulse |
| 5 | arx_pop__pop | 1 | unsigned | 0 | command_pulse |
| 37:6 | arx_error_count__count | 32 | unsigned | 0 | clear_mask |
| 69:38 | arx_overflow_count__count | 32 | unsigned | 0 | clear_mask |
| 70 | arx_status__pop_rejected | 1 | unsigned | 0 | W1C rejected empty-POP evidence |
| 102:71 | arx_rejected_access_count__count | 32 | unsigned | 0 | whole-counter clear for rejected queue access |
| 103 | rtl017_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |
| 104 | arx_status__snapshot_valid | 1 | unsigned | 0 | clear_mask |

### dfc_rtl017_status_t — 256 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | arx_status__enabled | 1 | unsigned | 0 | readback_value |
| 4 | arx_status__not_empty | 1 | unsigned | 0 | readback_value |
| 5 | arx_status__full | 1 | unsigned | 0 | readback_value |
| 6 | arx_status__snapshot_valid | 1 | unsigned | 0 | readback_value |
| 7 | arx_status__parity_error | 1 | unsigned | 0 | readback_value |
| 8 | arx_status__framing_error | 1 | unsigned | 0 | readback_value |
| 9 | arx_status__overrun | 1 | unsigned | 0 | readback_value |
| 10 | arx_status__adapter_error | 1 | unsigned | 0 | readback_value |
| 14:11 | arx_queue_level__level | 4 | unsigned | 0 | readback_value |
| 46:15 | arx_data__word | 32 | unsigned | 0 | readback_value |
| 47 | arx_meta__parity_ok | 1 | unsigned | 0 | readback_value |
| 48 | arx_meta__framing_ok | 1 | unsigned | 0 | readback_value |
| 49 | arx_meta__high_speed | 1 | unsigned | 0 | readback_value |
| 50 | arx_meta__error_present | 1 | unsigned | 0 | readback_value |
| 62:51 | arx_meta__error_code | 12 | unsigned | 0 | readback_value |
| 78:63 | arx_meta__sequence | 16 | unsigned | 0 | readback_value |
| 110:79 | arx_time_lo__timestamp_lo | 32 | unsigned | 0x00000000 | readback_value |
| 142:111 | arx_time_hi__timestamp_hi | 32 | unsigned | 0x00000000 | readback_value |
| 174:143 | arx_error_count__count | 32 | unsigned | 0 | readback_value |
| 206:175 | arx_overflow_count__count | 32 | unsigned | 0 | readback_value |
| 222:207 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 223 | arx_status__pop_rejected | 1 | unsigned | 0 | sticky rejected empty-POP evidence |
| 255:224 | arx_rejected_access_count__count | 32 | unsigned | 0 | saturating count of rejected queue accesses |

### `dfc_rtl018_control_t` — 163 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | atx_control__enable | 1 | unsigned | 0 | control_value |
| 1 | atx_control__high_speed | 1 | unsigned | 0 | control_value |
| 2 | atx_control__event_enable | 1 | unsigned | 0 | control_value |
| 3 | atx_control__irq_enable | 1 | unsigned | 0 | control_value |
| 4 | atx_control__auto_parity | 1 | unsigned | 1 | control_value |
| 5 | atx_status__complete | 1 | unsigned | 0 | clear_mask |
| 6 | atx_status__underrun | 1 | unsigned | 0 | clear_mask |
| 7 | atx_status__rejected | 1 | unsigned | 0 | clear_mask |
| 8 | atx_status__adapter_error | 1 | unsigned | 0 | clear_mask |
| 40:9 | atx_data_stage__word | 32 | unsigned | 0x00000000 | control_value |
| 41 | atx_meta_stage__parity_override_valid | 1 | unsigned | 0 | control_value |
| 42 | atx_meta_stage__parity_bit | 1 | unsigned | 0 | control_value |
| 56:43 | atx_meta_stage__tag | 14 | unsigned | 0 | control_value |
| 57 | atx_push__push | 1 | unsigned | 0 | command_pulse |
| 89:58 | atx_error_count__count | 32 | unsigned | 0 | clear_mask |
| 121:90 | atx_underrun_count__count | 32 | unsigned | 0 | clear_mask |
| 129:122 | atx_interword_gap_bits__gap_bits | 8 | unsigned | 4 | control_value |
| 161:130 | atx_rejected_push_count__count | 32 | unsigned | 0 | whole-counter clear for full or invalid PUSH rejection |
| 162 | rtl018_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |

### dfc_rtl018_status_t — 127 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | atx_status__enabled | 1 | unsigned | 0 | readback_value |
| 4 | atx_status__busy | 1 | unsigned | 0 | readback_value |
| 5 | atx_status__queue_empty | 1 | unsigned | 1 | readback_value |
| 6 | atx_status__queue_full | 1 | unsigned | 0 | readback_value |
| 7 | atx_status__complete | 1 | unsigned | 0 | readback_value |
| 8 | atx_status__underrun | 1 | unsigned | 0 | readback_value |
| 9 | atx_status__rejected | 1 | unsigned | 0 | readback_value |
| 10 | atx_status__adapter_error | 1 | unsigned | 0 | readback_value |
| 14:11 | atx_queue_level__level | 4 | unsigned | 0 | readback_value |
| 46:15 | atx_error_count__count | 32 | unsigned | 0 | readback_value |
| 78:47 | atx_underrun_count__count | 32 | unsigned | 0 | readback_value |
| 94:79 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 126:95 | atx_rejected_push_count__count | 32 | unsigned | 0 | saturating count of full or invalid PUSH rejection |

### `dfc_rtl019_control_t` — 204 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | can_control__enable | 1 | unsigned | 0 | control_value |
| 1 | can_control__loopback | 1 | unsigned | 0 | control_value |
| 2 | can_control__listen_only | 1 | unsigned | 0 | control_value |
| 3 | can_control__event_enable | 1 | unsigned | 0 | control_value |
| 4 | can_control__irq_enable | 1 | unsigned | 0 | control_value |
| 5 | can_status__rx_overflow | 1 | unsigned | 0 | clear_mask |
| 6 | can_status__tx_rejected | 1 | unsigned | 0 | clear_mask |
| 7 | can_status__protocol_error | 1 | unsigned | 0 | clear_mask |
| 8 | can_status__transceiver_error | 1 | unsigned | 0 | clear_mask |
| 18:9 | can_bit_timing__prescaler_minus_1 | 10 | unsigned | 0 | control_value |
| 24:19 | can_bit_timing__tseg1_minus_1 | 6 | unsigned | 0 | control_value |
| 29:25 | can_bit_timing__tseg2_minus_1 | 5 | unsigned | 0 | control_value |
| 33:30 | can_bit_timing__sjw_minus_1 | 4 | unsigned | 0 | control_value |
| 34 | can_rx_snapshot__capture | 1 | unsigned | 0 | command_pulse |
| 35 | can_rx_pop__pop | 1 | unsigned | 0 | command_pulse |
| 64:36 | can_tx_id_stage__identifier | 29 | unsigned | 0 | control_value |
| 65 | can_tx_id_stage__ide | 1 | unsigned | 0 | control_value |
| 66 | can_tx_id_stage__rtr | 1 | unsigned | 0 | control_value |
| 70:67 | can_tx_meta_stage__dlc | 4 | unsigned | 0 | control_value |
| 102:71 | can_tx_data_lo_stage__data_0_3 | 32 | unsigned | 0x00000000 | control_value |
| 134:103 | can_tx_data_hi_stage__data_4_7 | 32 | unsigned | 0x00000000 | control_value |
| 135 | can_tx_push__push | 1 | unsigned | 0 | command_pulse |
| 136 | can_control__automatic_bus_off_recovery | 1 | unsigned | 0 | control_value |
| 137 | can_recovery__request | 1 | unsigned | 0 | command_pulse |
| 138 | can_status__rx_pop_rejected | 1 | unsigned | 0 | W1C rejected empty-POP evidence |
| 170:139 | can_rx_overflow_count__count | 32 | unsigned | 0 | whole-counter clear |
| 202:171 | can_tx_rejected_count__count | 32 | unsigned | 0 | whole-counter clear |
| 203 | rtl019_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |

### dfc_rtl019_status_t — 326 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | can_status__enabled | 1 | unsigned | 0 | readback_value |
| 4 | can_status__rx_not_empty | 1 | unsigned | 0 | readback_value |
| 5 | can_status__tx_not_full | 1 | unsigned | 1 | readback_value |
| 6 | can_status__error_warning | 1 | unsigned | 0 | readback_value |
| 7 | can_status__error_passive | 1 | unsigned | 0 | readback_value |
| 8 | can_status__bus_off | 1 | unsigned | 0 | readback_value |
| 9 | can_status__rx_overflow | 1 | unsigned | 0 | readback_value |
| 10 | can_status__tx_rejected | 1 | unsigned | 0 | readback_value |
| 11 | can_status__protocol_error | 1 | unsigned | 0 | readback_value |
| 12 | can_status__transceiver_error | 1 | unsigned | 0 | readback_value |
| 20:13 | can_error_count__tx_error_count | 8 | unsigned | 0 | readback_value |
| 28:21 | can_error_count__rx_error_count | 8 | unsigned | 0 | readback_value |
| 44:29 | can_error_count__protocol_error_count | 16 | unsigned | 0 | readback_value |
| 48:45 | can_rx_level__level | 4 | unsigned | 0 | readback_value |
| 77:49 | can_rx_id__identifier | 29 | unsigned | 0 | readback_value |
| 78 | can_rx_id__ide | 1 | unsigned | 0 | readback_value |
| 79 | can_rx_id__rtr | 1 | unsigned | 0 | readback_value |
| 80 | can_rx_id__valid | 1 | unsigned | 0 | readback_value |
| 84:81 | can_rx_meta__dlc | 4 | unsigned | 0 | readback_value |
| 96:85 | can_rx_meta__flags | 12 | unsigned | 0 | readback_value |
| 112:97 | can_rx_meta__sequence | 16 | unsigned | 0 | readback_value |
| 144:113 | can_rx_data_lo__data_0_3 | 32 | unsigned | 0x00000000 | readback_value |
| 176:145 | can_rx_data_hi__data_4_7 | 32 | unsigned | 0x00000000 | readback_value |
| 208:177 | can_rx_time_lo__timestamp_lo | 32 | unsigned | 0x00000000 | readback_value |
| 240:209 | can_rx_time_hi__timestamp_hi | 32 | unsigned | 0x00000000 | readback_value |
| 244:241 | can_tx_level__level | 4 | unsigned | 0 | readback_value |
| 260:245 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 261 | can_status__rx_pop_rejected | 1 | unsigned | 0 | sticky rejected empty-POP evidence |
| 293:262 | can_rx_overflow_count__count | 32 | unsigned | 0 | saturating RX overflow/drop count |
| 325:294 | can_tx_rejected_count__count | 32 | unsigned | 0 | saturating full or invalid TX PUSH rejection count |

### dfc_rtl020_control_t — 216 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | uart_control__enable | 1 | unsigned | 0 | control_value |
| 2:1 | uart_control__parity | 2 | unsigned | 0 | control_value |
| 3 | uart_control__two_stop_bits | 1 | unsigned | 0 | control_value |
| 4 | uart_control__event_enable | 1 | unsigned | 0 | control_value |
| 5 | uart_control__irq_enable | 1 | unsigned | 0 | control_value |
| 6 | uart_status__framing_error | 1 | unsigned | 0 | clear_mask |
| 7 | uart_status__parity_error | 1 | unsigned | 0 | clear_mask |
| 8 | uart_status__rx_overflow | 1 | unsigned | 0 | clear_mask |
| 9 | uart_status__tx_underflow | 1 | unsigned | 0 | clear_mask |
| 10 | uart_status__break_detected | 1 | unsigned | 0 | clear_mask |
| 42:11 | uart_baud_div__divisor | 32 | unsigned | 434 | control_value |
| 43 | uart_rx_pop__pop | 1 | unsigned | 0 | command_pulse |
| 51:44 | uart_tx_data__data | 8 | unsigned | 0 | control_value |
| 52 | uart_tx_push__push | 1 | unsigned | 0 | command_pulse |
| 84:53 | uart_error_count__count | 32 | unsigned | 0 | clear_mask |
| 85 | uart_status__rx_underflow | 1 | unsigned | 0 | W1C rejected empty RX POP evidence |
| 86 | uart_status__tx_rejected | 1 | unsigned | 0 | W1C rejected full or invalid TX PUSH evidence |
| 118:87 | uart_rx_overflow_count__count | 32 | unsigned | 0 | whole-counter clear |
| 150:119 | uart_rx_underflow_count__count | 32 | unsigned | 0 | whole-counter clear |
| 182:151 | uart_tx_rejected_count__count | 32 | unsigned | 0 | whole-counter clear |
| 214:183 | uart_tx_underflow_count__count | 32 | unsigned | 0 | whole-counter clear |
| 215 | rtl020_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |

### dfc_rtl020_status_t — 217 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | uart_status__enabled | 1 | unsigned | 0 | readback_value |
| 4 | uart_status__rx_not_empty | 1 | unsigned | 0 | readback_value |
| 5 | uart_status__tx_not_full | 1 | unsigned | 1 | readback_value |
| 6 | uart_status__tx_busy | 1 | unsigned | 0 | readback_value |
| 7 | uart_status__framing_error | 1 | unsigned | 0 | readback_value |
| 8 | uart_status__parity_error | 1 | unsigned | 0 | readback_value |
| 9 | uart_status__rx_overflow | 1 | unsigned | 0 | readback_value |
| 10 | uart_status__tx_underflow | 1 | unsigned | 0 | readback_value |
| 11 | uart_status__break_detected | 1 | unsigned | 0 | readback_value |
| 16:12 | uart_rx_level__level | 5 | unsigned | 0 | readback_value |
| 24:17 | uart_rx_data__data | 8 | unsigned | 0 | readback_value |
| 32:25 | uart_rx_data__error_flags | 8 | unsigned | 0 | readback_value |
| 33 | uart_rx_data__valid | 1 | unsigned | 0 | readback_value |
| 38:34 | uart_tx_level__level | 5 | unsigned | 0 | readback_value |
| 70:39 | uart_error_count__count | 32 | unsigned | 0 | readback_value |
| 86:71 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 87 | uart_status__rx_underflow | 1 | unsigned | 0 | sticky rejected empty RX POP evidence |
| 88 | uart_status__tx_rejected | 1 | unsigned | 0 | sticky rejected full or invalid TX PUSH evidence |
| 120:89 | uart_rx_overflow_count__count | 32 | unsigned | 0 | saturating RX overflow/drop count |
| 152:121 | uart_rx_underflow_count__count | 32 | unsigned | 0 | saturating rejected empty RX POP count |
| 184:153 | uart_tx_rejected_count__count | 32 | unsigned | 0 | saturating full or invalid TX PUSH count |
| 216:185 | uart_tx_underflow_count__count | 32 | unsigned | 0 | saturating TX underflow count |

### dfc_rtl021_control_t — 136 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | route_control__enable | 1 | unsigned | 0 | control_value |
| 1 | route_control__event_enable | 1 | unsigned | 0 | control_value |
| 2 | route_control__irq_enable | 1 | unsigned | 0 | control_value |
| 3 | route_status__commit_complete | 1 | unsigned | 0 | clear_mask |
| 4 | route_status__commit_rejected | 1 | unsigned | 0 | clear_mask |
| 5 | route_status__dest_overflow | 1 | unsigned | 0 | clear_mask |
| 6 | route_status__unauthorized | 1 | unsigned | 0 | clear_mask |
| 10:7 | route_entry_select__entry | 4 | unsigned | 0 | control_value |
| 18:11 | route_stage_source__source_id | 8 | unsigned | 0 | control_value |
| 23:19 | route_stage_dest__dest_mask | 5 | unsigned | 0 | control_value |
| 55:24 | route_stage_type_mask__type_mask | 32 | unsigned | 0x00000000 | control_value |
| 87:56 | route_stage_filter_value__filter_value | 32 | unsigned | 0x00000000 | control_value |
| 119:88 | route_stage_filter_mask__filter_mask | 32 | unsigned | 0x00000000 | control_value |
| 120 | route_stage_control__enable | 1 | unsigned | 0 | control_value |
| 121 | route_stage_control__drop_on_full | 1 | unsigned | 0 | control_value |
| 122 | route_validate_commit__validate_commit | 1 | unsigned | 0 | command_pulse |
| 123 | route_validate_commit__disable_entry | 1 | unsigned | 0 | command_pulse |
| 124 | route_entry_status__error | 1 | unsigned | 0 | clear_mask |
| 129:125 | route_ingress_loss_count__clear | 5 | unsigned | 0 | one whole-counter-clear pulse per ingress source |
| 134:130 | route_destination_drop_count__clear | 5 | unsigned | 0 | one whole-counter-clear pulse per destination |
| 135 | rtl021_evt_overflow_status__event_overflow | 1 | unsigned | 0 | clear_mask |

### `dfc_rtl021_status_t` — 338 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | route_status__active | 1 | unsigned | 0 | readback_value |
| 4 | route_status__commit_complete | 1 | unsigned | 0 | readback_value |
| 5 | route_status__commit_rejected | 1 | unsigned | 0 | readback_value |
| 6 | route_status__dest_overflow | 1 | unsigned | 0 | readback_value |
| 7 | route_status__unauthorized | 1 | unsigned | 0 | readback_value |
| 15:8 | route_status__last_error | 8 | unsigned | 0 | readback_value |
| 31:16 | route_status__drop_count | 16 | unsigned | 0 | readback_value |
| 39:32 | route_active_source__source | 8 | unsigned | 0x00 | readback_value |
| 44:40 | route_active_dest__dest_mask | 5 | unsigned | 0x00 | readback_value |
| 76:45 | route_active_type_mask__type_mask | 32 | unsigned | 0x00000000 | readback_value |
| 108:77 | route_active_filter_value__filter_value | 32 | unsigned | 0x00000000 | readback_value |
| 140:109 | route_active_filter_mask__filter_mask | 32 | unsigned | 0x00000000 | readback_value |
| 141 | route_entry_status__active | 1 | unsigned | 0 | readback_value |
| 142 | route_entry_status__valid | 1 | unsigned | 0 | readback_value |
| 143 | route_entry_status__error | 1 | unsigned | 0 | readback_value |
| 159:144 | route_entry_status__forwarded_count | 16 | unsigned | 0 | readback_value |
| 175:160 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 255:176 | route_ingress_loss_count__count | 80 | unsigned | 0 | five packed 16-bit saturating counts, source IDs 0 through 4 in ascending slices |
| 335:256 | route_destination_drop_count__count | 80 | unsigned | 0 | five packed 16-bit saturating counts, destination IDs 0 through 4 in ascending slices |
| 336 | route_active_control__enable | 1 | unsigned | 0 | readback_value |
| 337 | route_active_control__drop_on_full | 1 | unsigned | 0 | readback_value |

### dfc_rtl022_control_t — 308 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | uli_control__enable | 1 | unsigned | 0 | control_value |
| 1 | uli_control__reset_req | 1 | unsigned | 0 | command_pulse |
| 2 | uli_control__event_enable | 1 | unsigned | 0 | control_value |
| 3 | uli_control__irq_enable | 1 | unsigned | 0 | control_value |
| 4 | uli_status__violation | 1 | unsigned | 0 | clear_mask |
| 5 | uli_status__reset_complete | 1 | unsigned | 0 | clear_mask |
| 37:6 | uli_param0__param0 | 32 | unsigned | 0x00000000 | control_value |
| 69:38 | uli_param1__param1 | 32 | unsigned | 0x00000000 | control_value |
| 101:70 | uli_param2__param2 | 32 | unsigned | 0x00000000 | control_value |
| 133:102 | uli_param3__param3 | 32 | unsigned | 0x00000000 | control_value |
| 165:134 | uli_param4__param4 | 32 | unsigned | 0x00000000 | control_value |
| 197:166 | uli_param5__param5 | 32 | unsigned | 0x00000000 | control_value |
| 229:198 | uli_param6__param6 | 32 | unsigned | 0x00000000 | control_value |
| 261:230 | uli_param7__param7 | 32 | unsigned | 0x00000000 | control_value |
| 293:262 | uli_in_data__mailbox_data | 32 | unsigned | 0x00000000 | control_value |
| 294 | uli_in_push__push | 1 | unsigned | 0 | command_pulse |
| 295 | uli_out_pop__pop | 1 | unsigned | 0 | command_pulse |
| 299:296 | uli_io_output__output_request | 4 | unsigned | 0 | control_value |
| 303:300 | uli_mailbox_status__overflow_underflow_clear | 4 | unsigned | 0 | W1C input overflow, input underflow, output overflow, output underflow evidence |
| 307:304 | uli_mailbox_loss_count__clear | 4 | unsigned | 0 | one whole-counter-clear pulse for each mailbox loss class |

### dfc_rtl022_status_t — 137 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | uli_status__enabled | 1 | unsigned | 0 | readback_value |
| 4 | uli_status__ready | 1 | unsigned | 0 | readback_value |
| 5 | uli_status__in_mailbox_not_empty | 1 | unsigned | 0 | readback_value |
| 6 | uli_status__out_mailbox_not_empty | 1 | unsigned | 0 | readback_value |
| 7 | uli_status__in_mailbox_full | 1 | unsigned | 0 | readback_value |
| 8 | uli_status__out_mailbox_full | 1 | unsigned | 0 | readback_value |
| 9 | uli_status__violation | 1 | unsigned | 0 | readback_value |
| 10 | uli_status__reset_complete | 1 | unsigned | 0 | readback_value |
| 13:11 | uli_in_level__level | 3 | unsigned | 0 | readback_value |
| 16:14 | uli_out_level__level | 3 | unsigned | 0 | readback_value |
| 48:17 | uli_out_data__mailbox_data | 32 | unsigned | 0x00000000 | readback_value |
| 52:49 | uli_io_input__input | 4 | unsigned | 0 | readback_value |
| 68:53 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 72:69 | uli_mailbox_status__overflow_underflow | 4 | unsigned | 0 | sticky input overflow, input underflow, output overflow, output underflow evidence |
| 136:73 | uli_mailbox_loss_count__count | 64 | unsigned | 0 | four packed 16-bit saturating counts in evidence-bit order |

### dfc_rtl023_control_t — 34 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | uroute_control__enable | 1 | unsigned | 0 | control_value |
| 1 | uroute_control__event_enable | 1 | unsigned | 0 | control_value |
| 2 | uroute_control__irq_enable | 1 | unsigned | 0 | control_value |
| 3 | uroute_status__commit_complete | 1 | unsigned | 0 | clear_mask |
| 4 | uroute_status__commit_rejected | 1 | unsigned | 0 | clear_mask |
| 5 | uroute_status__forbidden_dest | 1 | unsigned | 0 | clear_mask |
| 6 | uroute_status__conflict | 1 | unsigned | 0 | clear_mask |
| 10:7 | uroute_entry_select__entry | 4 | unsigned | 0 | control_value |
| 18:11 | uroute_stage_source__source_id | 8 | unsigned | 0 | control_value |
| 26:19 | uroute_stage_dest__dest_id | 8 | unsigned | 0 | control_value |
| 27 | uroute_stage_control__enable | 1 | unsigned | 0 | control_value |
| 28 | uroute_stage_control__invert | 1 | unsigned | 0 | control_value |
| 30:29 | uroute_stage_control__mode | 2 | unsigned | 0 | control_value |
| 31 | uroute_validate_commit__validate_commit | 1 | unsigned | 0 | command_pulse |
| 32 | uroute_validate_commit__disable_entry | 1 | unsigned | 0 | command_pulse |
| 33 | uroute_entry_status__error | 1 | unsigned | 0 | clear_mask |

### `dfc_rtl023_status_t` — 75 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | uroute_status__active | 1 | unsigned | 0 | readback_value |
| 4 | uroute_status__commit_complete | 1 | unsigned | 0 | readback_value |
| 5 | uroute_status__commit_rejected | 1 | unsigned | 0 | readback_value |
| 6 | uroute_status__forbidden_dest | 1 | unsigned | 0 | readback_value |
| 7 | uroute_status__conflict | 1 | unsigned | 0 | readback_value |
| 23:8 | uroute_status__violation_count | 16 | unsigned | 0 | readback_value |
| 31:24 | uroute_active_source__source_id | 8 | unsigned | 0x00 | readback_value |
| 39:32 | uroute_active_dest__dest_id | 8 | unsigned | 0x00 | readback_value |
| 40 | uroute_entry_status__active | 1 | unsigned | 0 | readback_value |
| 41 | uroute_entry_status__valid | 1 | unsigned | 0 | readback_value |
| 42 | uroute_entry_status__error | 1 | unsigned | 0 | readback_value |
| 58:43 | uroute_entry_status__activity_count | 16 | unsigned | 0 | readback_value |
| 74:59 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |

### dfc_rtl024_control_t — 278 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | host_status__response_truncated | 1 | unsigned | 0 | clear_mask |
| 1 | host_control__event_enable | 1 | unsigned | 0 | control_value |
| 2 | host_control__irq_enable | 1 | unsigned | 0 | control_value |
| 3 | host_status__invalid_opcode | 1 | unsigned | 0 | clear_mask |
| 4 | host_status__invalid_length | 1 | unsigned | 0 | clear_mask |
| 5 | host_status__unaligned | 1 | unsigned | 0 | clear_mask |
| 6 | host_status__invalid_address | 1 | unsigned | 0 | clear_mask |
| 7 | host_status__access_error | 1 | unsigned | 0 | clear_mask |
| 8 | host_status__protected_error | 1 | unsigned | 0 | clear_mask |
| 9 | host_status__crc_error | 1 | unsigned | 0 | clear_mask |
| 10 | host_status__timeout | 1 | unsigned | 0 | clear_mask |
| 11 | host_status__endpoint_error | 1 | unsigned | 0 | clear_mask |
| 12 | host_status__aborted | 1 | unsigned | 0 | clear_mask |
| 44:13 | host_completed_count__count | 32 | unsigned | 0 | clear_mask |
| 76:45 | host_crc_error_count__count | 32 | unsigned | 0 | clear_mask |
| 108:77 | host_abort_count__count | 32 | unsigned | 0 | clear_mask |
| 140:109 | host_timeout_count__count | 32 | unsigned | 0 | clear_mask |
| 172:141 | host_access_error_count__count | 32 | unsigned | 0 | clear_mask |
| 173 | test_control__enable | 1 | unsigned | 0 | control_value |
| 174 | test_control__loopback_enable | 1 | unsigned | 0 | control_value |
| 175 | test_control__injection_enable | 1 | unsigned | 0 | control_value |
| 176 | test_status__command_complete | 1 | unsigned | 0 | clear_mask |
| 177 | test_status__command_rejected | 1 | unsigned | 0 | clear_mask |
| 178 | test_status__safety_blocked | 1 | unsigned | 0 | clear_mask |
| 186:179 | test_command__command | 8 | unsigned | 0 | command_pulse |
| 210:187 | test_command__argument | 24 | unsigned | 0 | command_pulse |
| 218:211 | test_loopback__loopback_select | 8 | unsigned | 0 | control_value |
| 223:219 | reserved_arx_control_migrated | 5 | unsigned | 0 | reserved -- real ARX_CONTROL fields moved to the dedicated dfc_rtl024_arinc_rx_adapter_control_t struct (see SS12's own adapter struct definitions) once reggen.py's whole-struct-coverage requirement made keeping them inside this general-purpose struct impractical for an incremental, module-by-module rollout |
| 227:224 | test_status__extended_evidence_clear | 4 | unsigned | 0 | W1C unsafe rejection, deauthorization abort, natural-fault, injected-fault evidence |
| 259:228 | test_rejection_abort_count__count | 32 | unsigned | 0 | whole-counter clear |
| 261:260 | clock_reset_status__evidence_clear | 2 | unsigned | 0 | W1C clock-fault and illegal-release evidence |
| 268:262 | buffer_status__client_error_clear | 7 | unsigned | 0 | W1C per-client error evidence |
| 269 | buffer_status__internal_error_clear | 1 | unsigned | 0 | W1C internal service error evidence |
| 276:270 | buffer_client_error_count__clear | 7 | unsigned | 0 | one whole-counter-clear pulse per client |
| 277 | buffer_internal_error_count__clear | 1 | unsigned | 0 | whole-counter-clear pulse |

### `dfc_rtl024_status_t` — 467 bits

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | ready | 1 | unsigned | 0 | module_status |
| 1 | fault | 1 | unsigned | 0 | module_status |
| 2 | event_overflow | 1 | unsigned | 0 | module_status |
| 3 | host_status__ready | 1 | unsigned | 0 | readback_value |
| 4 | host_status__busy | 1 | unsigned | 0 | readback_value |
| 5 | host_status__invalid_opcode | 1 | unsigned | 0 | readback_value |
| 6 | host_status__invalid_length | 1 | unsigned | 0 | readback_value |
| 7 | host_status__unaligned | 1 | unsigned | 0 | readback_value |
| 8 | host_status__invalid_address | 1 | unsigned | 0 | readback_value |
| 9 | host_status__access_error | 1 | unsigned | 0 | readback_value |
| 10 | host_status__protected_error | 1 | unsigned | 0 | readback_value |
| 11 | host_status__crc_error | 1 | unsigned | 0 | readback_value |
| 12 | host_status__timeout | 1 | unsigned | 0 | readback_value |
| 13 | host_status__endpoint_error | 1 | unsigned | 0 | readback_value |
| 14 | host_status__aborted | 1 | unsigned | 0 | readback_value |
| 15 | host_status__response_truncated | 1 | unsigned | 0 | readback_value |
| 23:16 | host_last_result__spi_status | 8 | unsigned | 0 | terminal reconciliation SPI status |
| 26:24 | host_last_result__dri_code | 3 | unsigned | 0 | terminal reconciliation endpoint result |
| 31:27 | host_last_result__completed_count | 5 | unsigned | 0 | terminal reconciliation completed-word count |
| 39:32 | host_last_result__opcode | 8 | unsigned | 0 | terminal reconciliation accepted opcode |
| 50:40 | host_last_result__sequence | 11 | unsigned | 0 | terminal reconciliation transaction sequence |
| 82:51 | host_last_address__address | 32 | unsigned | 0 | terminal reconciliation starting byte address |
| 114:83 | host_completed_count__count | 32 | unsigned | 0 | saturating count of successful terminal accepted commands |
| 146:115 | host_crc_error_count__count | 32 | unsigned | 0 | readback_value |
| 178:147 | host_abort_count__count | 32 | unsigned | 0 | readback_value |
| 210:179 | host_timeout_count__count | 32 | unsigned | 0 | readback_value |
| 242:211 | host_access_error_count__count | 32 | unsigned | 0 | readback_value |
| 243 | test_status__physical_auth | 1 | unsigned | 0 | readback_value |
| 244 | test_status__active | 1 | unsigned | 0 | readback_value |
| 245 | test_status__command_complete | 1 | unsigned | 0 | readback_value |
| 246 | test_status__command_rejected | 1 | unsigned | 0 | readback_value |
| 247 | test_status__safety_blocked | 1 | unsigned | 0 | readback_value |
| 254:248 | buffer_status__client_error | 7 | unsigned | 0 | readback_value |
| 255 | buffer_status__internal_error | 1 | unsigned | 0 | readback_value |
| 271:256 | event_drop_count | 16 | unsigned | 0 | saturating count of records lost while this producer pending slot was occupied |
| 272 | host_last_result__valid | 1 | unsigned | 0 | terminal host-reconciliation record valid |
| 273 | test_status__busy | 1 | unsigned | 0 | current command activity |
| 274 | test_status__unsafe_rejected | 1 | unsigned | 0 | sticky unsafe-command rejection evidence |
| 275 | test_status__deauthorization_aborted | 1 | unsigned | 0 | sticky deauthorization-abort evidence |
| 276 | test_status__loopback_active | 1 | unsigned | 0 | current qualified loopback state |
| 277 | test_status__injection_enabled | 1 | unsigned | 0 | current qualified injection permission |
| 278 | test_status__natural_fault_observed | 1 | unsigned | 0 | sticky natural-fault evidence during authorized test |
| 279 | test_status__injected_fault_observed | 1 | unsigned | 0 | sticky accepted-injection evidence |
| 287:280 | test_status__terminal_reason | 8 | unsigned | 0 | ARCH-TEST-018 terminal result |
| 319:288 | test_rejection_abort_count__count | 32 | unsigned | 0 | saturating rejected-or-aborted test-command count |
| 320 | clock_reset_status__clock_fault_active | 1 | unsigned | 0 | current platform-reported clock fault |
| 321 | clock_reset_status__clock_fault_sticky | 1 | unsigned | 0 | retained invalid/lost-clock evidence |
| 322 | clock_reset_status__illegal_release | 1 | unsigned | 0 | retained illegal reset-release evidence |
| 434:323 | buffer_client_error_count__count | 112 | unsigned | 0 | seven packed 16-bit saturating client-error counts, clients 0 through 6 in ascending slices |
| 466:435 | buffer_internal_error_count__count | 32 | unsigned | 0 | saturating shared-buffer internal-error count |

### dfc_rtl024_arinc_rx_adapter_control_t — 5 bits

Dedicated struct for `ARCH-BUS-001`'s real digital receive adapter (an
internal RTL-024 subblock, not a separate RTL-0NN module -- same
"internal subblock" status as the shared-buffer service, SS12). Carries
exactly `ARX_CONTROL`'s (REG-002 0x1000) five real fields, migrated out
of the general-purpose `dfc_rtl024_control_t` (see that struct's own
`reserved_arx_control_migrated` placeholder) once `reggen.py`'s
whole-struct-coverage requirement made keeping them inside a 278-bit
catch-all struct impractical for an incremental, module-by-module
rollout -- every other module's own control/status struct is already
scoped to exactly its own subsystem; this gives the adapter the same
treatment.

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | arx_control__enable | 1 | unsigned | 0 | control_value |
| 1 | arx_control__high_speed | 1 | unsigned | 0 | control_value |
| 2 | arx_control__event_enable | 1 | unsigned | 0 | control_value |
| 3 | arx_control__irq_enable | 1 | unsigned | 0 | control_value |
| 4 | arx_control__accept_parity_error | 1 | unsigned | 0 | control_value |

### dfc_rtl024_arinc_rx_adapter_status_t — 1 bits

`reggen.py`'s cross-module forwarding mechanism requires a named status
struct for every consumer regardless of whether that consumer has any
real status content to report -- `ARX_CONTROL`'s own readback class is
`internal_reg` (REG-002: the regbank stores and returns its written value
directly), so the adapter has no real external status field to expose
yet. One honestly-labeled reserved bit, not an invented signal.

| **Bits** | **Member** | **W** | **Signedness** | **Reset** | **Semantic** |
| --- | --- | --- | --- | --- | --- |
| 0 | reserved_no_status_yet | 1 | unsigned | 0 | reserved -- no real adapter status field exists yet; placeholder only to satisfy reggen.py's named-status-struct requirement |

### dfc_safety_response_req_t — 8 bits

| **Bits** | **Member** | **W** |
| --- | --- | --- |
| 3:0 | response_mask | 4 |
| 6:4 | source_id | 3 |
| 7 | valid | 1 |


# Appendix C — Fixed Source and Endpoint Allocations

### C.1 Internal signal-source numeric allocation

| **ID/bit** | **Source** | **Exact producer** |
| --- | --- | --- |
| 0 | Constant false | constant_zero |
| 1–8 | Qualified GPIO 0–7 | RTL-006.status_o.gpio_qual_in__qual_input[0..7] |
| 9–16 | Qualified health 0–7 | RTL-011.status_o.health_qual_in__qualified[0..7] |
| 17 | Rotor low | RTL-007.status_o.rotor_status__low |
| 18 | Rotor high | RTL-007.status_o.rotor_status__high |
| 19 | Engine low | RTL-008.status_o.engine_status__low |
| 20 | Engine high | RTL-008.status_o.engine_status__high |
| 21 | Pulse 0 low | RTL-009.status_o.pulse0_status__low |
| 22 | Pulse 0 high | RTL-009.status_o.pulse0_status__high |
| 23 | Pulse 1 low | RTL-009.status_o.pulse1_status__low |
| 24 | Pulse 1 high | RTL-009.status_o.pulse1_status__high |
| 25 | Sensor 0 low | RTL-010.status_o.sensor0_status__low |
| 26 | Sensor 0 high | RTL-010.status_o.sensor0_status__high |
| 27 | Sensor 1 low | RTL-010.status_o.sensor1_status__low |
| 28 | Sensor 1 high | RTL-010.status_o.sensor1_status__high |
| 29 | Watchdog timeout | RTL-012.status_o.wdog_status__timeout |
| 30 | Any lost link | reduction-OR RTL-015.status_o.llink_status__lost_active[7:0] |
| 31 | Fault active | RTL-013.status_o.fault_status__fault_active |
| 32 | Any interlock violation | reduction-OR RTL-014.status_o.ilock_status__violation_active[7:0] |
| 33–36 | User logic output 0–3 | RTL-022.user_o[0..3] |
| 37 | Constant true | constant_one |
| 38–63 | Reserved | constant_zero; programming these IDs is invalid |

### C.2 User-route destination numeric allocation

| **ID/bit** | **Destination** | **Exact consumer** |
| --- | --- | --- |
| 0 | No action | no consumer; safe reset/default |
| 1–8 | GPIO request 0–7 | RTL-006.route_gpio_req_i[0..7] |
| 9–12 | User-I/O request 0–3 | RTL-022.route_user_req_i[0..3] |
| 13–20 | User-logic term 0–7 | RTL-022.route_term_i[0..7] |
| 21–22 | User-route event request 0–1 | RTL-023 internal event-request channels |
| 23–24 | User-route interrupt request 0–1 | RTL-023 internal interrupt-request channels |
| 25–31 | Reserved | inactive; programming these IDs is invalid |

### C.3 Interlock term whitelist

| **ID set** | **Disposition** |
| --- | --- |
| 0–31 and 37 | Legal interlock term source IDs |
| 32 | Illegal: prevents direct combinational self-reference |
| 33–36 | Illegal: prevents unreviewed user-logic feedback into safety interlocks |
| 38–255 | Illegal/reserved; validation or commit rejected with no partial state change |


### C.4 Interrupt source endpoint matrix

| **Bit** | **Source** | **Producer** | **Port** | **Semantics** | **Clear/reassert** |
| --- | --- | --- | --- | --- | --- |
| 0 | System Control | RTL-002 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 1 | Event Logger | RTL-005 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 2 | GPIO | RTL-006 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 3 | ARINC RX | RTL-017 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 4 | ARINC TX | RTL-018 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 5 | CAN | RTL-019 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 6 | UART | RTL-020 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 7 | Databus Routing | RTL-021 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 8 | Rotor RPM | RTL-007 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 9 | Engine RPM | RTL-008 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 10 | Pulse/Frequency | RTL-009 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 11 | Sensor Monitor | RTL-010 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 12 | System Health | RTL-011 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 13 | Watchdog | RTL-012 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 14 | Fault Manager | RTL-013 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 15 | Interlock | RTL-014 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 16 | Lost Link | RTL-015 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 17 | Safety Output | RTL-016 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 18 | Mask-Defined User Logic | RTL-022 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 19 | User Routing | RTL-023 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 20 | Host Interface | RTL-024 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 21 | Configuration Error | RTL-001 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 22 | Clock/Reset Integration | RTL-024 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 23 | Production Test | RTL-024 | irq_req_o | qualified source level or sticky evidence; active condition may reassert after clear | W1C after acknowledgement; new assertion dominates |
| 24 | Reserved | Tied inactive | constant_zero | reserved inactive | writes of one rejected |
| 25 | Reserved | Tied inactive | constant_zero | reserved inactive | writes of one rejected |
| 26 | Reserved | Tied inactive | constant_zero | reserved inactive | writes of one rejected |
| 27 | Reserved | Tied inactive | constant_zero | reserved inactive | writes of one rejected |
| 28 | Reserved | Tied inactive | constant_zero | reserved inactive | writes of one rejected |
| 29 | Reserved | Tied inactive | constant_zero | reserved inactive | writes of one rejected |
| 30 | Reserved | Tied inactive | constant_zero | reserved inactive | writes of one rejected |
| 31 | Reserved | Tied inactive | constant_zero | reserved inactive | writes of one rejected |


### C.5 Event source endpoint matrix

| **Index** | **Source ID** | **Producer** | **Allowed event IDs** | **Pending/arbitration** | **Overflow route** |
| --- | --- | --- | --- | --- | --- |
| 0 | 0x01 | RTL-001 | 0x0002; 0x0003 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-001.status_o.event_overflow; EVT_DROP_SOURCE[0]; saturating source loss count |
| 1 | 0x02 | RTL-002 | 0x0001; 0x0004 | one stable pending record; reset > fault/illegal > degraded > test > startup/normal; state event 0x0001 and reset event 0x0004; handshake clears record only | occupied-slot arrivals increment saturating loss count, set event_overflow, and schedule 0x007E; disabled normal events are suppressed without overflow; safety/overflow bypass |
| 2 | 0x03 | RTL-003 | 0x0008; 0x007E | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-003.status_o.event_overflow; EVT_DROP_SOURCE[2]; saturating source loss count |
| 3 | 0x04 | RTL-004 | 0x0009; 0x007E | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-004.status_o.event_overflow; EVT_DROP_SOURCE[3]; saturating source loss count |
| 4 | 0x05 | RTL-005 | 0x000A; 0x007E; 0x007F | event-store overflow has priority over source overflow; internally generated overflow records use the nonrecursive path in ARCH-EVT-007 | RTL-005.status_o.event_overflow; EVT_DROP_SOURCE[4]; saturating source and store loss counts |
| 5 | 0x06 | RTL-006 | 0x0010 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-006.status_o.event_overflow; EVT_DROP_SOURCE[5]; saturating source loss count |
| 6 | 0x07 | RTL-007 | 0x0030 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-007.status_o.event_overflow; EVT_DROP_SOURCE[6]; saturating source loss count |
| 7 | 0x08 | RTL-008 | 0x0031 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-008.status_o.event_overflow; EVT_DROP_SOURCE[7]; saturating source loss count |
| 8 | 0x09 | RTL-009 | 0x0032 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-009.status_o.event_overflow; EVT_DROP_SOURCE[8]; saturating source loss count |
| 9 | 0x0A | RTL-010 | 0x0033 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-010.status_o.event_overflow; EVT_DROP_SOURCE[9]; saturating source loss count |
| 10 | 0x0B | RTL-011 | 0x0034 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-011.status_o.event_overflow; EVT_DROP_SOURCE[10]; saturating source loss count |
| 11 | 0x0C | RTL-012 | 0x0040 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-012.status_o.event_overflow; EVT_DROP_SOURCE[11]; saturating source loss count |
| 12 | 0x0D | RTL-013 | 0x0041 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-013.status_o.event_overflow; EVT_DROP_SOURCE[12]; saturating source loss count |
| 13 | 0x0E | RTL-014 | 0x0042 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-014.status_o.event_overflow; EVT_DROP_SOURCE[13]; saturating source loss count |
| 14 | 0x0F | RTL-015 | 0x0043 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-015.status_o.event_overflow; EVT_DROP_SOURCE[14]; saturating source loss count |
| 15 | 0x10 | RTL-016 | 0x0044 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-016.status_o.event_overflow; EVT_DROP_SOURCE[15]; saturating source loss count |
| 16 | 0x11 | RTL-017 | 0x0020 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-017.status_o.event_overflow; EVT_DROP_SOURCE[16]; saturating source loss count |
| 17 | 0x12 | RTL-018 | 0x0021 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-018.status_o.event_overflow; EVT_DROP_SOURCE[17]; saturating source loss count |
| 18 | 0x13 | RTL-019 | 0x0022 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-019.status_o.event_overflow; EVT_DROP_SOURCE[18]; saturating source loss count |
| 19 | 0x14 | RTL-020 | 0x0023 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-020.status_o.event_overflow; EVT_DROP_SOURCE[19]; saturating source loss count |
| 20 | 0x15 | RTL-021 | 0x0024 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-021.status_o.event_overflow; EVT_DROP_SOURCE[20]; saturating source loss count |
| 21 | 0x16 | RTL-022 | 0x0050 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-022.status_o.event_overflow; EVT_DROP_SOURCE[21]; saturating source loss count |
| 22 | 0x17 | RTL-023 | 0x0051 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-023.status_o.event_overflow; EVT_DROP_SOURCE[22]; saturating source loss count |
| 23 | 0x18 | RTL-024 | 0x0005; 0x0006; 0x0007 | one complete stable 128-bit record; 24-source rotating round-robin; one accept per CORE_CLK | RTL-024.status_o.event_overflow; EVT_DROP_SOURCE[23]; saturating source loss count |


### C.6 Fault source endpoint matrix

Fault-class encodings are `0x00` none/reserved, `0x02` measurement or sampled-sensor fault, `0x03` communication or routing fault, `0x04` safety-supervision fault, `0x05` evidence-storage fault, `0x06` health/discrete fault, and `0x7F` nonrecoverable bounded-user violation. Every other class value is reserved.

| **Bit** | **Fault** | **Producer** | **Port** | **Class** | **Active/latch/recovery** | **Clear/reassert** |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | Watchdog timeout | RTL-012 | fault_req_o | 0x04 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 1 | Interlock violation | RTL-014 | fault_req_o | 0x04 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 2 | Lost-link condition | RTL-015 | fault_req_o | 0x03 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 3 | Safety-output configuration error | RTL-016 | fault_req_o | 0x04 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 4 | System-health aggregate fault | RTL-011 | fault_req_o | 0x06 | active condition plus RTL-013 sticky evidence; recoverable=false | eligible host clear; active source remains or relatches; new detection dominates |
| 5 | Event logger overflow | RTL-005 | fault_req_o | 0x05 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 6 | Rotor RPM abnormal/error | RTL-007 | fault_req_o | 0x02 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 7 | Engine RPM abnormal/error | RTL-008 | fault_req_o | 0x02 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 8 | Pulse/frequency abnormal/error | RTL-009 | fault_req_o | 0x02 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 9 | Sensor abnormal/configuration error | RTL-010 | fault_req_o | 0x02 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 10 | ARINC RX error | RTL-017 | fault_req_o | 0x03 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 11 | ARINC TX error | RTL-018 | fault_req_o | 0x03 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 12 | CAN error or bus-off | RTL-019 | fault_req_o | 0x03 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 13 | UART error | RTL-020 | fault_req_o | 0x03 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 14 | Databus routing error | RTL-021 | fault_req_o | 0x03 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 15 | Mask-defined user-logic error | RTL-022 | fault_req_o | 0x7F | active condition plus RTL-013 sticky evidence; recoverable=false | eligible host clear; active source remains or relatches; new detection dominates |
| 16 | User-routing error | RTL-023 | fault_req_o | 0x03 | active condition plus RTL-013 sticky evidence; recoverable=true | eligible host clear; active source remains or relatches; new detection dominates |
| 17 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 18 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 19 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 20 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 21 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 22 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 23 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 24 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 25 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 26 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 27 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 28 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 29 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 30 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |
| 31 | Reserved | Tied inactive | constant_zero | 0x00 | inactive | writes of one rejected |


### C.7 Event identifier and data-format registry

Every listed ID is legal only for the producer(s) identified in C.5. Event IDs not listed are reserved and shall not be emitted. `event_data[7:0]` is subtype, `[15:8]` is channel or originating source index, and `[31:16]` is event-specific detail unless the row defines a more specific use.

| Event ID | Event class | Legal subtype values | `event_data[31:16]` detail |
|---:|---|---|---|
| `0x0001` | Operating-state transition | 0 entry, 1 exit, 2 degraded acknowledge | prior and new three-bit states packed in bits 2:0 and 6:4 |
| `0x0002` | Configuration transaction | 0 accepted, 1 rejected, 2 protected failure | low sixteen bits of register word offset |
| `0x0003` | Register endpoint/protection error | 0 decode, 1 access, 2 protection, 3 endpoint, 4 timeout | DRI code and first-error code |
| `0x0004` | Controlled reset | 0 requested, 1 complete, 2 rejected, 3 timeout, 4 recovery failure | reset-scope bit index and result |
| `0x0005` | SPI host transaction | 0 accepted, 1 complete, 2 rejected, 3 timeout, 4 pre-acceptance abort, 5 response truncation, 6 CRC error, 7 access/protection failure, 8 endpoint failure | reconciliation sequence, status, and completed count |
| `0x0006` | Clock/reset integration | 0 release, 1 illegal release attempt, 2 clock fault, 3 clock recovery | integration status and source |
| `0x0007` | Production test | 0 authorized, 1 deauthorized, 2 complete, 3 rejected, 4 aborted, 5 safety blocked, 6 unsafe rejected, 7 natural fault observed, 8 injected fault observed | opcode and ARCH-TEST-018 result |
| `0x0008` | Interrupt controller | 0 reserved-source attempt, 1 illegal injection, 2 vector-state error | source and result |
| `0x0009` | Timestamp | 0 correlation commit, 1 arithmetic error, 2 snapshot complete | update sequence or error detail |
| `0x000A` | Event logger operation | 0 not-empty transition, 1 pop error, 2 clear complete | level and operation result |
| `0x0010` | GPIO | 0 rising, 1 falling, 2 high level, 3 low level | qualified GPIO bitmap |
| `0x0020` | ARINC receive | 0 word, 1 overflow, 2 parity, 3 framing, 4 adapter error, 5 recovery | sequence and error flags |
| `0x0021` | ARINC transmit | 0 complete, 1 rejected, 2 overflow, 3 underrun, 4 adapter error, 5 recovery | sequence and result |
| `0x0022` | CAN | 0 receive, 1 transmit, 2 arbitration loss, 3 protocol error, 4 overflow, 5 bus-off, 6 recovery, 7 transceiver error | sequence and CAN error state |
| `0x0023` | UART | 0 receive, 1 transmit, 2 framing, 3 parity, 4 overflow, 5 underflow, 6 break, 7 recovery | sequence and error flags |
| `0x0024` | Message routing | 0 commit, 1 reject, 2 forward, 3 drop, 4 filter mismatch, 5 unauthorized | route entry and destination |
| `0x0030` | Rotor RPM | 0 low, 1 high, 2 timeout, 3 updated, 4 saturation, 5 recovery, 6 configuration reject | saturated RPM |
| `0x0031` | Engine RPM | 0 low, 1 high, 2 timeout, 3 updated, 4 saturation, 5 recovery, 6 configuration reject | saturated RPM |
| `0x0032` | Pulse/frequency | 0 low, 1 high, 2 timeout, 3 updated, 4 saturation, 5 recovery, 6 configuration reject | upper sixteen bits of Q17.15 value |
| `0x0033` | Sampled sensor | 0 low, 1 high, 2 stale, 3 invalid, 4 updated, 5 recovery, 6 rejected | source and sequence low bits |
| `0x0034` | Health/discrete | 0 asserted, 1 deasserted, 2 qualification failure, 3 recovery | active and sticky masks |
| `0x0040` | Watchdog | 0 early, 1 late, 2 missing/timeout, 3 invalid key, 4 recovered, 5 service accepted | elapsed-time low bits |
| `0x0041` | Fault manager | 0 asserted, 1 recovered, 2 cleared, 3 response requested | fault bit and class |
| `0x0042` | Interlock | 0 violation, 1 satisfied/recovered, 2 commit accepted, 3 commit rejected | expression and error code |
| `0x0043` | Lost link | 0 lost, 1 recovered, 2 configuration rejected, 3 injection | elapsed-time low bits |
| `0x0044` | Safety output | 0 request, 1 activation, 2 inhibited, 3 deactivation, 4 configuration rejected | requested/effective/inhibit summary |
| `0x0050` | User Logic Island | 0 diagnostic input, 1 mailbox, 2 parameter rejected, 3 reset | mailbox level or parameter index |
| `0x0051` | User signal routing | 0 commit, 1 reject, 2 activity, 3 conflict, 4 forbidden destination | entry and destination |
| `0x007E` | Producer-slot overflow | 0 only | Saturating source-loss count low sixteen bits |
| `0x007F` | Event-store overwrite | 0 only | Saturating store-overflow count low sixteen bits |

### C.8 Safety-response authorization allocation

| Mask bits | Producer/source | Disposition |
|---:|---|---|
| 0 | RTL-012 lane 0, source 0 | Legal watchdog authorization |
| 1–7 | Lane 0 reserved sources | Reserved; write rejected |
| 8 | RTL-013 lane 1, source 0 | Legal aggregate fault-manager authorization |
| 9–15 | Lane 1 reserved sources | Reserved; write rejected |
| 16–23 | RTL-014 lane 2, interlocks 0–7 | Legal per-interlock authorization |
| 24–31 | RTL-015 lane 3, lost-link monitors 0–7 | Legal per-monitor authorization |

# Appendix D — Module Readiness and Reset Scope

## D.1 Module readiness and reset-scope matrix

| **Bit** | **Module** | **Class** | **Host-ready** | **Startup** | **Ready/fault ports** | **Reset request/ack** | **Timeout/restriction** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | RTL-001 | mandatory | True | True | RTL-001.status_o.ready; RTL-001.status_o.fault | N/A — no module_reset_i; system reset only | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 1 | RTL-002 | mandatory | True | True | RTL-002.status_o.ready; RTL-002.status_o.fault | RTL-002.module_reset_o[1] -> RTL-002.module_reset_i (system-only) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 2 | RTL-003 | mandatory | False | True | RTL-003.status_o.ready; RTL-003.status_o.fault | RTL-002.module_reset_o[2] -> RTL-003.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 3 | RTL-004 | mandatory | False | True | RTL-004.status_o.ready; RTL-004.status_o.fault | RTL-002.module_reset_o[3] -> RTL-004.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 4 | RTL-005 | mandatory | False | True | RTL-005.status_o.ready; RTL-005.status_o.fault | RTL-002.module_reset_o[4] -> RTL-005.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 5 | RTL-006 | optional | False | False | RTL-006.status_o.ready; RTL-006.status_o.fault | RTL-002.module_reset_o[5] -> RTL-006.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 6 | RTL-007 | optional | False | False | RTL-007.status_o.ready; RTL-007.status_o.fault | RTL-002.module_reset_o[6] -> RTL-007.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 7 | RTL-008 | optional | False | False | RTL-008.status_o.ready; RTL-008.status_o.fault | RTL-002.module_reset_o[7] -> RTL-008.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 8 | RTL-009 | optional | False | False | RTL-009.status_o.ready; RTL-009.status_o.fault | RTL-002.module_reset_o[8] -> RTL-009.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 9 | RTL-010 | optional | False | False | RTL-010.status_o.ready; RTL-010.status_o.fault | RTL-002.module_reset_o[9] -> RTL-010.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 10 | RTL-011 | optional | False | False | RTL-011.status_o.ready; RTL-011.status_o.fault | RTL-002.module_reset_o[10] -> RTL-011.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 11 | RTL-012 | mandatory | False | True | RTL-012.status_o.ready; RTL-012.status_o.fault | RTL-002.module_reset_o[11] -> RTL-012.module_reset_i (safety-scope) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 12 | RTL-013 | mandatory | False | True | RTL-013.status_o.ready; RTL-013.status_o.fault | RTL-002.module_reset_o[12] -> RTL-013.module_reset_i (safety-scope) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 13 | RTL-014 | mandatory | False | True | RTL-014.status_o.ready; RTL-014.status_o.fault | RTL-002.module_reset_o[13] -> RTL-014.module_reset_i (safety-scope) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 14 | RTL-015 | mandatory | False | True | RTL-015.status_o.ready; RTL-015.status_o.fault | RTL-002.module_reset_o[14] -> RTL-015.module_reset_i (safety-scope) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 15 | RTL-016 | mandatory | False | True | RTL-016.status_o.ready; RTL-016.status_o.fault | RTL-002.module_reset_o[15] -> RTL-016.module_reset_i (safety-scope) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 16 | RTL-017 | optional | False | False | RTL-017.status_o.ready; RTL-017.status_o.fault | RTL-002.module_reset_o[16] -> RTL-017.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 17 | RTL-018 | optional | False | False | RTL-018.status_o.ready; RTL-018.status_o.fault | RTL-002.module_reset_o[17] -> RTL-018.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 18 | RTL-019 | optional | False | False | RTL-019.status_o.ready; RTL-019.status_o.fault | RTL-002.module_reset_o[18] -> RTL-019.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 19 | RTL-020 | optional | False | False | RTL-020.status_o.ready; RTL-020.status_o.fault | RTL-002.module_reset_o[19] -> RTL-020.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 20 | RTL-021 | optional | False | False | RTL-021.status_o.ready; RTL-021.status_o.fault | RTL-002.module_reset_o[20] -> RTL-021.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 21 | RTL-022 | optional | False | False | RTL-022.status_o.ready; RTL-022.status_o.fault | RTL-002.module_reset_o[21] -> RTL-022.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 22 | RTL-023 | optional | False | False | RTL-023.status_o.ready; RTL-023.status_o.fault | RTL-002.module_reset_o[22] -> RTL-023.module_reset_i (individually commandable) | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |
| 23 | RTL-024 | mandatory | True | True | RTL-024.status_o.ready; RTL-024.status_o.fault | N/A — no module_reset_i; system reset only | Timing per DFC-PERF-0001 through DFC-PERF-0003; reset scope and state priority per ARCH-RST-004 through ARCH-RST-006 and ARCH-STATE-001 through ARCH-STATE-007 |


# Appendix E — CDC/RDC Inventory

## E.1 Endpoint CDC/RDC inventory

| **ID** | **Source domain** | **Destination domain** | **Data class** | **Mechanism** | **Reset/reconvergence** | **Constraints** |
| --- | --- | --- | --- | --- | --- | --- |
| CDC-001 | RTL-024 SPI shift engine / SPI_SCLK | RTL-024 core executor / CORE_CLK | validated SPI request payload and ownership | stable multi-bit request mailbox plus synchronized ownership toggle and acknowledgement | spi_rst_n/core_rst_n return mailbox empty; aborted ownership cannot create DRI activity; payload remains stable from ownership transfer until core acknowledgement; toggle and payload reconverge only after two-flop toggle synchronization | asynchronous clock groups; mailbox stability and synchronizer exceptions reviewed |
| CDC-002 | RTL-024 core response / CORE_CLK | RTL-024 SPI response shifter / SPI_SCLK | SPI status, completed count, read payload, response CRC input | stable multi-bit response mailbox plus synchronized ownership toggle and acknowledgement | either reset flushes ownership; no stale response is shifted after a new transaction; response stable until SPI acknowledgement; synchronized toggle gates capture | asynchronous clock groups; mailbox stability and synchronizer exceptions reviewed |
| CDC-CLOCK | Platform clock monitor / asynchronous or monitor reference | RTL-024 clock diagnostic / CORE_CLK | active-high clock-fault level held across recovered clock edges | two-stage synchronizer followed by sticky capture; platform holds assertion through at least four valid CORE_CLK edges after recovery | POR clears synchronized and sticky state; current level and sticky evidence remain independently visible | false path to first synchronizer stage; source-hold and synchronizer placement review |
| RDC-001 | OpenFrame POR / asynchronous | core_rst_n / CORE_CLK modules | functional reset release | asynchronous assertion, per-domain synchronized release after at least four valid CORE_CLK edges | primary reset; all CORE_CLK modules observe the same qualified release epoch | recovery/removal and reset-tree analysis |
| RDC-002 | Platform POR / asynchronous | SPI shift domain / SPI_SCLK may stop | SPI reset release | asynchronous assertion and idle-window release; no SPI_SCLK-clocked release dependency; one-microsecond CS-high/SCLK-low qualification in CORE_CLK | mailbox ownership returns empty; any overlapping CS interval is nonframing | recovery/removal; idle-window and ARCH-SPI-018 proof |
| CDC-ARINC | external arinc_rx_i / asynchronous | RTL-024 ARINC adapter / CORE_CLK | asynchronous digital input | multi-sample timing-recovery synchronizer | ignored until synchronized reset release and qualification complete; independent bits unless protocol/qualifier explicitly reassembles data | false path to first synchronizer stage; synchronizer placement/MTBF review |
| CDC-CAN | external can_rx_i / asynchronous | RTL-019 / CORE_CLK | asynchronous digital input | protocol-qualified synchronizer | ignored until synchronized reset release and qualification complete; independent bits unless protocol/qualifier explicitly reassembles data | false path to first synchronizer stage; synchronizer placement/MTBF review |
| CDC-UART | external uart_rx_i / asynchronous | RTL-020 / CORE_CLK | asynchronous digital input | oversampling synchronizer | ignored until synchronized reset release and qualification complete; independent bits unless protocol/qualifier explicitly reassembles data | false path to first synchronizer stage; synchronizer placement/MTBF review |
| CDC-PULSE | external rotor_i/engine_i/pulse_i[1:0] / asynchronous | RTL-007/008/009 / CORE_CLK | asynchronous digital input | two-stage synchronizer plus edge qualification | ignored until synchronized reset release and qualification complete; independent bits unless protocol/qualifier explicitly reassembles data | false path to first synchronizer stage; synchronizer placement/MTBF review |
| CDC-GPIO | external gpio_i[7:0] / asynchronous | RTL-006 / CORE_CLK | asynchronous digital input | per-bit two-stage synchronizer plus programmed qualification | ignored until synchronized reset release and qualification complete; independent bits unless protocol/qualifier explicitly reassembles data | false path to first synchronizer stage; synchronizer placement/MTBF review |
| CDC-HEALTH | external health_i[7:0] / asynchronous | RTL-011 / CORE_CLK | asynchronous digital input | per-bit two-stage synchronizer plus stable-time qualification | ignored until synchronized reset release and qualification complete; independent bits unless protocol/qualifier explicitly reassembles data | false path to first synchronizer stage; synchronizer placement/MTBF review |
| CDC-USER | external user_i[3:0] / asynchronous | RTL-022 / CORE_CLK | diagnostic digital inputs | per-bit two-stage synchronizer | ignored until synchronized reset release; no operational output in Revision A | false path to first stage; synchronizer placement/MTBF review |
| CDC-ARXERR | external ARINC RX adapter error / asynchronous | RTL-017 path / CORE_CLK | single-bit level | two-stage synchronizer; registered in RTL-024 | reset clears synchronized and sticky evidence | false path to first stage; synchronizer placement/MTBF review |
| CDC-ATXERR | external ARINC TX adapter error / asynchronous | RTL-018 path / CORE_CLK | single-bit level | two-stage synchronizer; registered in RTL-024 | reset clears synchronized and sticky evidence | false path to first stage; synchronizer placement/MTBF review |
| CDC-CANERR | external CAN transceiver error / asynchronous | RTL-019 path / CORE_CLK | single-bit level | two-stage synchronizer; registered in RTL-024 | reset clears synchronized and sticky evidence | false path to first stage; synchronizer placement/MTBF review |
| CDC-TEST-001 | TEST_ENABLE and TEST_DATA command / asynchronous or TEST_CLK | core test controller / CORE_CLK | authorization level and complete 32-bit command | authorization two-stage synchronizer plus four-cycle qualifier; command stable-payload ownership toggle | deauthorization asynchronously disables TEST_DATA output and flushes both ownership states | asynchronous clock groups; payload-stability and synchronizer exceptions |
| CDC-TEST-002 | Core diagnostic sources / CORE_CLK | test shift register / TEST_CLK | atomic 256-bit capture vector | core snapshot register plus request/acknowledgement toggle; TEST_CLK captures only after synchronized snapshot-valid | reset/deauthorization cancels request; payload held stable until acknowledgement; no independent reconvergence | asynchronous clock groups; 256-bit payload stability proof |
| CDC-TEST-003 | Test shift completion / TEST_CLK | core test status / CORE_CLK | completion, rejection, shifted count, and result summary | stable payload plus completion toggle and acknowledgement | reset/deauthorization flushes completion; result stable through acknowledgement | asynchronous clock groups; payload-stability and synchronizer exceptions |
| RDC-TEST-001 | Platform POR or TEST_ENABLE deauthorization / asynchronous | test-domain state / TEST_CLK may stop | test reset and output-enable release | asynchronous assertion; TEST_CLK-synchronized release only after physical authorization; output enable additionally ANDed with asynchronous authorization | test state returns idle; TEST_DATA output enable falls without TEST_CLK | recovery/removal; deauthorization-to-high-impedance timing proof |

No synchronized control may qualify an independently changing unsynchronized bus. No first-stage synchronizer output is used functionally. Reconvergent synchronized signals are permitted only where captured from the same stable source epoch and identified above.

# Appendix F — Module State, Reset, and Simultaneous-Condition Contracts

## F.1 Per-module derivation contracts

| Contract ID | Module | Reset and priority-specific derivation contract |
|---|---|---|
| ARCH-RTL001-001 | RTL-001 | First-error order is alignment, decode, access, reserved, range, protection, busy, endpoint. Reset cancels DRI and proxy commands before any side effect. Accepted DRI commit dominates ordinary status sampling; reset dominates commit. |
| ARCH-RTL002-001 | RTL-002 | State transition priority is Section 4.1. Controlled reset busy rejects another request. Terminal result and newly detected timeout or recovery failure dominate result/evidence clear. Ready is host-path initialized AND state logic initialized; fault is illegal state OR reset timeout OR mandatory startup/loss fault. |
| ARCH-RTL003-001 | RTL-003 | RAW/LATCH/PENDING/ACKED equations are Section 8.1. Reset clears all state. New raw dominates clear; clear dominates acknowledgement for an inactive source. Ready is high after vector initialization; fault is reserved/internal illegal-state evidence. |
| ARCH-RTL004-001 | RTL-004 | Divider, snapshot, correlation, and priority are ARCH-TIME-001 through ARCH-TIME-006. Ready is high after release; fault is illegal command or correlation arithmetic/control error. |
| ARCH-RTL005-001 | RTL-005 | Arbitration, store, snapshot/pop/clear, and overflow priority are ARCH-EVT-001 through ARCH-EVT-008. Ready is high after pointers and pending slots clear; fault is retained internal-storage/control error or configured event-overflow fault condition. |
| ARCH-RTL006-001 | RTL-006 | Synchronization, qualification, direction ownership, commanded/effective output reporting, output gating, and event equations are ARCH-MON-001. Reset and disable force OE zero before evaluating routes or output data. Ready requires legal channel configuration; fault is illegal configuration or unrecoverable qualification logic error. |
| ARCH-RTL007-001 | RTL-007 | Edge, measurement, rounding, saturation, timeout, and threshold rules are ARCH-MON-002 through ARCH-MON-005. Reset clears history/valid. A newly committed measurement precedes threshold event evaluation. |
| ARCH-RTL008-001 | RTL-008 | Same as RTL-007 with the engine range and configuration. Separate state prevents rotor/engine coupling. |
| ARCH-RTL009-001 | RTL-009 | Each channel independently applies ARCH-MON-002, ARCH-MON-004, and ARCH-MON-005. Same-cycle accepted edges update both channel states independently. |
| ARCH-RTL010-001 | RTL-010 | Signed comparison, hysteresis, stale, and update arbitration are ARCH-MON-006 and ARCH-MON-007. Host commit precedes routed commit, then age tick, threshold evaluation, and evidence clear. |
| ARCH-RTL011-001 | RTL-011 | Qualification, qualification-attempt failure, and active/sticky/recovery equations are ARCH-MON-008. New active or qualification failure dominates clear; recovery is captured as sticky evidence and does not clear asserted evidence. Aggregate fault is a registered OR of enabled active channels. |
| ARCH-RTL012-001 | RTL-012 | Service-window and key behavior is ARCH-SAFE-005. Reset/disable clears timer and request. Timeout detection precedes same-cycle late service; exactly-on-boundary service is legal at MIN and legal through MAX-1. |
| ARCH-RTL013-001 | RTL-013 | Fault allocation, recoverability, primary selection, and clear rules are Section 10.1 and C.6. New active dominates clear; lowest bit selects primary; active source identity is retained in event data. |
| ARCH-RTL014-001 | RTL-014 | Commit and evaluation are ARCH-SAFE-006. Reset clears active expressions to disabled. COMMIT validates then atomically replaces all eight entries before the next evaluation; violation on the new bank may assert on that next edge. |
| ARCH-RTL015-001 | RTL-015 | Activity mapping, timers, recovery, and injection are ARCH-SAFE-007 and ARCH-SAFE-008. Natural loss has priority over injected evidence; clear never suppresses an active loss. |
| ARCH-RTL016-001 | RTL-016 | Authorization, requested/latched/commanded/effective state, polarity, cause-specific inhibit, and output equations are Section 10.4. Reset/test/inhibit dominate request. Multiple authorized requests OR; one source cannot cancel another. |
| ARCH-RTL017-001 | RTL-017 | Accepted adapter word is written completely to ARCH-BUF-003 before RX tail/valid advances. Full queue rejects and increments overflow count. POP reads the oldest complete entry before advancing head; POP on empty sets rejected-access evidence and count. Route-source transfer and host POP independently reference the same head and only one removal may commit per cycle. |
| ARCH-RTL018-001 | RTL-018 | Host or route request is validated then written completely to ARCH-BUF-004 before TX tail advances. A full or invalid host PUSH sets rejection evidence and count. Host push has priority over route input only when both target the last free slot; the losing route remains backpressured and is not counted as lost. TX removes only after complete serialization or explicit rejected result; an attempted dequeue while empty sets underrun evidence and count. |
| ARCH-RTL019-001 | RTL-019 | RX and TX queues use ARCH-BUF-005/006. Protocol state writes complete frames before valid. RX overflow/drop and empty POP are independently evidenced and counted. Full or invalid TX PUSH is evidenced and counted. Host TX push has priority over route input for the last slot; a backpressured route is not counted as lost. Bus-off forces recessive output and blocks dequeue until recovery. Natural protocol error dominates host error clear. |
| ARCH-RTL020-001 | RTL-020 | RX/TX bytes use ARCH-BUF-007/008. A received byte plus flags becomes valid atomically after stop-bit evaluation. RX overflow/drop, empty RX POP, full or invalid TX PUSH, and TX underflow are independently evidenced and counted. Host TX push has priority over route input for the last slot; a backpressured route is not counted as lost. Disable completes the current transmitted character then idles high; reset aborts immediately. |
| ARCH-RTL021-001 | RTL-021 | Ingress, filter, replication, arbitration, and backpressure follow ARCH-ROUTE-001 through ARCH-ROUTE-008 using ARCH-BUF-009/010. Each source ingress and destination queue owns its indexed 16-bit saturating loss count. Commit replaces all sixteen entries atomically; an in-flight record completes under the configuration epoch captured at ingress acceptance. |
| ARCH-RTL022-001 | RTL-022 | Revision A equations are ARCH-ULI-001 through ARCH-ULI-005 using ARCH-BUF-011. Every operational output is constant inactive. Diagnostic mailbox push/pop obey full/empty rules and complete-entry visibility; input and output overflow and underflow are independently evidenced and counted. |
| ARCH-RTL023-001 | RTL-023 | Authorization, exclusivity, wired-OR, mode, disable, and command priority are Section 13.2. Edge history updates while enabled even when effective outputs are gated, preventing a stale edge on re-enable. |
| ARCH-RTL024-001 | RTL-024 | Instantiates RTL-001 through RTL-023, connects Appendix A interfaces, implements Sections 5–7, 12, 14, and 15, and owns all pad-safe gates. Ready requires reset, host mailboxes, DRI, shared buffer, reconciliation state, clock diagnostics, and test controller initialized. Fault is host timeout/internal error OR shared-buffer internal error OR reset/clock/test integration error. |

## F.2 Common queue simultaneity

| Pre-state | Push only | Pop only | Simultaneous push and pop |
|---|---|---|---|
| Empty | Accept push; level 1 | Reject and set underflow | Accept push, reject pop, level 1; no pass-through |
| 1 through depth minus 1 | Accept; level +1 | Accept; level -1 | Pop old head, append new tail, level unchanged |
| Full | Reject and set overflow | Accept; level -1 | Pop old head, append new tail, level unchanged |

The event-store overwrite exception is governed only by ARCH-EVT-005 through ARCH-EVT-007. Every other queue uses this table. A rejected empty pop increments that resource's underflow or rejected-access counter; a rejected full push increments its overflow or rejected-access counter. A simultaneous push/pop accepted in the table increments no loss counter. New evidence or count increment dominates simultaneous clear.

## F.3 Event and interrupt subcondition masks

RTL-001 stores one 64-bit event-condition mask and one 64-bit interrupt-condition mask for each RTL index. A listed bit independently enables that subcondition. Unlisted bits are reserved zero and a write setting one is rejected. Existing module/channel `EVENT_ENABLE` and `IRQ_ENABLE` fields are master gates; effective ordinary qualification is the applicable master/channel enable AND the corresponding condition-mask bit. Safety-mandatory events and `0x007E`/`0x007F` overflow events bypass ordinary event gating. The module equations are:

`evt_request = mandatory_event | (GLOBAL_EVENT_ENABLE & MODULE_EVENT_ENABLE & |(EVENT_CONDITION & EVENT_MASK))`

`irq_req = MODULE_IRQ_ENABLE & |(IRQ_CONDITION & IRQ_MASK)`

For per-channel master enables, the corresponding channel master replaces `MODULE_*_ENABLE`. RTL-003 latches the resulting module request according to Section 8.1.

| RTL | Condition-mask bit allocation; same allocation for event and interrupt unless stated |
|---|---|
| RTL-001 | 0 decode error; 1 access error; 2 protected error; 3 endpoint error; 4 timeout; 5 configuration rejection; 6 event-slot overflow |
| RTL-002 | 0 state entry; 1 state exit; 2 reset complete; 3 reset rejected; 4 reset timeout; 5 startup failure; 6 event-slot overflow; 7 reset-recovery failure |
| RTL-003 | 0 illegal reserved-source activity; 1 event-slot overflow; other bits reserved; no self-interrupt is generated |
| RTL-004 | 0 correlation commit; 1 correlation arithmetic error; 2 snapshot complete; 3 event-slot overflow; no ordinary interrupt is generated |
| RTL-005 | 0 not-empty transition; 1 store overflow; 2 producer drop; 3 pop error; 4 clear complete; 5 event-slot overflow |
| RTL-006 | 0–7 rising channels 0–7; 8–15 falling; 16–23 active-high level; 24–31 active-low level; 32–39 either-edge; 40 event-slot overflow |
| RTL-007 | 0 low; 1 high; 2 timeout; 3 updated; 4 recovery; 5 saturation/range; 6 event-slot overflow |
| RTL-008 | 0 low; 1 high; 2 timeout; 3 updated; 4 recovery; 5 saturation/range; 6 event-slot overflow |
| RTL-009 | 0–5 channel 0 low/high/timeout/updated/recovery/saturation; 8–13 channel 1 in the same order; 16 event-slot overflow |
| RTL-010 | 0–3 sensor 0 low/high/stale/invalid; 8–11 sensor 1 in the same order; 16 update accepted; 17 update rejected; 18 event-slot overflow |
| RTL-011 | 0–7 asserted channels 0–7; 8–15 deasserted/recovered; 16–23 qualification failure; 24 event-slot overflow |
| RTL-012 | 0 early; 1 late/missing; 2 invalid key; 3 timeout; 4 recovery; 5 service accepted; 6 event-slot overflow |
| RTL-013 | 0–16 fault-source assertion; 32–48 corresponding recovery; 49 multiple fault; 50 response pending; 51 event-slot overflow |
| RTL-014 | 0–7 violations; 8–15 recoveries; 16 commit complete; 17 commit rejected; 18 event-slot overflow |
| RTL-015 | 0–7 lost monitors; 8–15 recovered monitors; 16 configuration rejection; 17 injected evidence; 18 event-slot overflow |
| RTL-016 | 0–3 request channels; 4–7 activations; 8–11 inhibited; 12–15 deactivated; 16–19 configuration rejected; 20 event-slot overflow |
| RTL-017 | 0 word received; 1 queue overflow; 2 parity; 3 framing; 4 adapter error; 5 recovery; 6 shared-buffer error; 7 event-slot overflow |
| RTL-018 | 0 transmit complete; 1 rejected; 2 queue overflow; 3 underrun; 4 adapter error; 5 recovery; 6 shared-buffer error; 7 event-slot overflow |
| RTL-019 | 0 receive; 1 transmit; 2 arbitration loss; 3 protocol error; 4 queue overflow; 5 bus-off; 6 recovery; 7 transceiver error; 8 shared-buffer error; 9 event-slot overflow |
| RTL-020 | 0 receive; 1 transmit; 2 framing; 3 parity; 4 overflow; 5 underflow; 6 break; 7 recovery; 8 shared-buffer error; 9 event-slot overflow |
| RTL-021 | 0 commit; 1 reject; 2 forward; 3 drop; 4 filter mismatch; 5 unauthorized; 6 shared-buffer error; 7 event-slot overflow |
| RTL-022 | All operational bits reserved because Revision A is inert; bit 0 parameter rejection, bit 1 diagnostic mailbox activity, bit 2 reset complete, bit 3 shared-buffer error, bit 4 event-slot overflow are diagnostic-event-only and never assert IRQ |
| RTL-023 | 0 commit; 1 reject; 2 routed activity; 3 conflict; 4 forbidden destination; 5 event-slot overflow |
| RTL-024 | 0 host accepted; 1 host complete; 2 host rejected; 3 host timeout; 4 pre-acceptance abort; 5 response truncation; 6 CRC error; 7 host access/protection/endpoint error; 8 clock/reset release; 9 clock fault; 10 illegal reset release; 16 test authorization; 17 deauthorization; 18 test complete; 19 test rejected; 20 test abort; 21 safety blocked; 22 shared-buffer error; 23 event-slot overflow; 24 unsafe test rejection; 25 natural fault observed; 26 injected fault observed |

## F.4 Configuration validation and first-error order

| Contract ID | Owner | Legal configuration and validation point |
|---|---|---|
| ARCH-VAL-001 | RTL-001 | Self-contained writes reject reserved ones, illegal range, or invalid access at write acceptance. Staged objects are range-checked again at commit. First error is retained until explicitly cleared. |
| ARCH-VAL-002 | RTL-002 | Module-enable bits 0, 1, 3, 4, and 11–15, 23 are mandatory and cannot be cleared. Reset scope must be exactly one legal scope; zero, multiple, or busy requests are rejected. |
| ARCH-VAL-003 | RTL-003 | Enable, ACK, CLEAR, or injection masks setting bits 24–31 are rejected. Injection also requires qualified test-active. |
| ARCH-VAL-004 | RTL-004 | Raw-time enable is constant one. Correlation offset accepts every signed 64-bit value; COMMIT requires protected authorization and a complete staged value. |
| ARCH-VAL-005 | RTL-005 | Overwrite-oldest is constant enabled. Source-enable bits 0–23 are legal; other bits are rejected. POP requires nonempty and SNAPSHOT requires nonempty. |
| ARCH-VAL-006 | RTL-006 | Qualification is 0–100 ms. Rising, falling, either-edge, active-high, and active-low qualification is selected independently by the F.3 condition masks and per-channel master enables. Output direction is legal only when the attached logical pad is assigned GPIO. |
| ARCH-VAL-007 | RTL-007 | `0 ≤ LOW ≤ HIGH ≤ 1000`, `HYST ≤ HIGH-LOW`, PPR 1–65535 when enabled, qualification 0–100 ms, and nonzero timeout when enabled. |
| ARCH-VAL-008 | RTL-008 | `0 ≤ LOW ≤ HIGH ≤ 20000`, `HYST ≤ HIGH-LOW`, PPR 1–65535 when enabled, qualification 0–100 ms, and nonzero timeout when enabled. |
| ARCH-VAL-009 | RTL-009 | Each Q17.15 threshold lies from 0.5 through 100000 Hz, LOW ≤ HIGH, HYST ≤ HIGH-LOW, qualification 0–100 ms, and nonzero timeout when enabled. |
| ARCH-VAL-010 | RTL-010 | Signed LOW ≤ signed HIGH; hysteresis is nonnegative and no greater than the signed interval without overflow. Source is 0–127, sequence is 24 bits, and commit requires all staged update members. |
| ARCH-VAL-011 | RTL-011 | Qualification is 0–100 ms; each event/IRQ mask may set only the F.3 bits allocated to RTL-011. |
| ARCH-VAL-012 | RTL-012 | `MIN_WINDOW_US < MAX_WINDOW_US`, MAX is nonzero, response mask is four bits, and service key is exact. Enable or recovery command with invalid timing is rejected. |
| ARCH-VAL-013 | RTL-013 | Source/configuration masks may set only bits 0–16; recoverability readback is fixed `0x00017FEF`; injection requires test-active; response request mask is four bits. |
| ARCH-VAL-014 | RTL-014 | Entry 0–7, operator 0–3, term IDs per C.3, nonzero legal guard mask, four-bit response mask, and zero reserved bits are validated for all eight entries at COMMIT_ALL. Within an entry the field order is TERM0, TERM1, TERM2, TERM3, OPERATOR, then the enabled-entry nonzero-guard relation. The first error is reported as an entry index and a code — 1–4 TERM0–TERM3 illegal, 5 OPERATOR illegal, 6 enabled entry with zero guard mask; 0 none; 7–15 reserved — retained in ILOCK_STATUS.FIRST_ERROR_ENTRY/FIRST_ERROR_CODE and in event 0x0042 subtype 3 detail until COMMIT_REJECTED is cleared. |
| ARCH-VAL-015 | RTL-015 | Monitor 0–7, activity source 0–7, `QUALIFY_US < TIMEOUT_US`, nonzero timeout, nonzero recovery interval, four-bit response mask, and legal injection are required. |
| ARCH-VAL-016 | RTL-016 | Channel 0–3, legal active polarity, 32-bit authorization with only C.8 legal bits, eight-bit interlock mask, and no nonzero response mask for a disabled channel. |
| ARCH-VAL-017 | RTL-017 | RX speed is low or high, parity acceptance is Boolean, and queue commands require the applicable nonempty state. Adapter metadata errors do not make an illegal configuration legal. |
| ARCH-VAL-018 | RTL-018 | Speed is low or high, gap is 4–255 bit times, parity override requires AUTO_PARITY zero and override-valid one, and PUSH requires a free queue entry. |
| ARCH-VAL-019 | RTL-019 | Timing, loopback/listen-only, identifier, IDE, RTR, DLC, data, and recovery are validated by Section 11.4. PUSH requires a free TX entry. |
| ARCH-VAL-020 | RTL-020 | BAUD_DIV is 50–50000; parity is 0–2; stop count is one or two; reserved error-flag and mask bits are zero; PUSH requires TX space. |
| ARCH-VAL-021 | RTL-021 | Entry 0–15, source 0–4, nonzero five-bit destination mask, defined type bits only, fixed matrix authorization, legal filter, and zero reserved fields are validated before atomic commit. |
| ARCH-VAL-022 | RTL-022 | All functional parameters and output requests are zero. Nonzero values are rejected. Diagnostic mailbox push/pop additionally require not-full/not-empty. |
| ARCH-VAL-023 | RTL-023 | Entry, source, destination, mode, fixed authorization, exclusive-destination uniqueness, and zero reserved fields are validated across the complete staged bank. |
| ARCH-VAL-024 | RTL-024 | SPI, test, loopback, shared-buffer, pad-control, and ARINC adapter controls are validated by Sections 6, 11, 12, and 14 before any operational action. |

Within a staged object, first-error priority is reserved field, selected index, range, cross-field relation, authorization, resource state, then busy. A commit result is one cycle, retained in status, and dominates simultaneous result clear.
