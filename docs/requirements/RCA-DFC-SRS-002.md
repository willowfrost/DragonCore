# Dragon Core System Requirements Specification

- **Document ID:** RCA-DFC-SRS-002
- **Product:** Dragon Core Revision A
- **Program:** Dragon Flight Core ASIC Development Program
- **Organization:** Royal Cubit Aerospace
- **Purpose:** Define the complete externally observable functional behavior, capacities, performance, timing, safety behavior, reliability behavior, environmental constraints, and external logical interfaces of Dragon Core Revision A.

## 1. Purpose

This System Requirements Specification is the sole normative owner of externally observable Dragon Core Revision A behavior and quantitative system constraints. It defines the behavior visible at the Dragon Core logical wrapper, external pads, and host-visible programming boundary, including safe and abnormal behavior.

This specification does not redefine the product mission or exclusions, responsibility allocation, internal decomposition, internal interfaces, algorithms, state encodings, numeric source allocations, register layout, implementation rules, verification methods, or trace relationships. Those subjects remain with the owners assigned by `RCA-DFC-CHTR-002`, Section 3.

The requirements in this specification are sufficient to derive the externally observable obligations of the Architecture Specification, Register Map Specification, RTL module specifications, RTL, host-interface artifacts, external host-software requirements that interact with Dragon Core, and verification cases without introducing new product behavior.

This specification defines the complete device-side contract needed by external software. It does not prescribe the external software architecture, application programming interfaces, task or thread model, persistence schema, operating-system integration, installation-specific configuration policy, maintenance workflow, or aircraft application policy. Those software-design subjects belong to subordinate software specifications under the responsibility allocations in `RCA-DFC-PBIO-002`.

## 2. Normative Language and Specification Relationships

The terms **shall** and **shall not** identify mandatory requirements. **Should** identifies a preferred technical approach. **May** identifies a permitted option.

This specification applies the single-owner rules `CHTR-DOC-001` through `CHTR-DOC-007` and preserves the processor-free, platform, external-host, boundary, and completeness constraints identified by `CHTR-TECH-001` through `CHTR-TECH-016` and `CHTR-PRN-001` through `CHTR-PRN-010`.

Responsibility for every boundary named here is allocated by `RCA-DFC-PBIO-002`. In particular:

- Dragon Core owns only the product-specific digital behavior assigned by `PBIO-ASIC-002`, `PBIO-HOST-001`, `PBIO-HOST-005`, `PBIO-INT-001` through `PBIO-INT-005`, and the applicable interface-ownership records in the PBIO Specification.
- RTL-024 owns logical-wrapper integration as assigned by `PBIO-INT-001` through `PBIO-INT-005` and the applicable interface-ownership records.
- Electrical adaptation, aircraft wiring, power drive, physical pad realization, external software, and physical ASIC implementation remain with the owners assigned by the PBIO Specification.
- The centralized shared-buffer service and the RTL-005 event-store exception are responsibility allocations controlled by `PBIO-MEM-001` through `PBIO-MEM-009`; their internal mechanisms and numeric map are owned by the Architecture Specification.

Named commands, status concepts, and configuration concepts in this SRS identify required behavior. Register offsets, fields, access classes, reset values, legal encodings, and side effects are owned by `RCA-DFC-REG-002`. Internal module allocation, interfaces, protocols, source identifiers, numeric event identifiers, arbitration, state machines, and simultaneous-condition priority are owned by `RCA-DFC-ARCH-002` unless a result is explicitly required at an external boundary here.

## 3. Definitions and Conventions

| Term | Definition |
|---|---|
| Accepted host command | A complete SPI command whose framing, length, opcode, address rules, and command CRC have been validated while chip select remains asserted and whose execution has begun or has produced a definitive rejection status. |
| Active condition | A currently asserted hardware condition evaluated from current qualified inputs, active configuration, and current internal state. An active condition is distinct from historical sticky evidence. |
| Authorized operation | An operation permitted by the active configuration and, where required, a valid protected-write or test-authorization condition. |
| Canonical message | The fixed 192-bit internal message representation used for bounded databus routing. Its field layout and numeric encodings are owned by the Architecture Specification. |
| Commanded state | The requested action after application of request selection and latch policy but before enable, inhibit, interlock, fault, reset, observation, and test gating. |
| Conditioned digital input | A digital signal already protected, limited, translated, and shaped for connection to a device pad as allocated by the PBIO Specification. |
| Correlated timestamp | The raw timestamp plus the active signed host-correlation offset; correlation never changes the raw timestamp. |
| Definitive transaction status | Exactly one status code that reports success or the applicable failure class for an accepted SPI command. |
| Dragon Core logical wrapper | The technology-independent top-level logical interface implemented by RTL-024 and preserved by FPGA and ASIC wrappers. |
| Effective state | The functional action remaining after enable, operating-state, inhibit, interlock, fault, reset, observation, and test gating. For a logical safety output, effective state reports active versus inactive before conversion through configured output polarity; external-pad logical level is a separate interface result. |
| Effective operational enable | The internally distributed permission for externally effective operational actions, derived from the host operational enable and system state as specified herein. |
| External host | A computing system outside the fabricated Dragon Core device that configures, services, and observes Dragon Core. |
| Host-reconciliation record | The coherent tuple for the most recent terminal accepted SPI command consisting of transaction sequence, opcode, starting address, completed-word count, SPI status, and internal endpoint result. |
| Inhibited state | A requested action prevented from becoming effective by one or more independently reportable gating causes. |
| Latched request state | A retained requested state that persists according to the configured latch and recovery policy after the initiating source is no longer active. |
| Logical safety output | A low-voltage digital command that requires external circuitry to control aircraft energy. |
| Mask-defined user logic | Finite hardware whose structure is fixed by fabrication masks and cannot be structurally reprogrammed after fabrication. |
| Observational mode | A mode that permits monitoring, communication reception, evidence collection, and host observation while inhibiting operational safety-output activation and other externally effective actions identified by the Architecture Specification. |
| Pending evidence | A retained indication awaiting its defined service, acknowledgement, clear, or source-clearing condition. |
| Qualification failure | A retained indication that an enabled finite qualification interval completed without the input satisfying the Architecture-defined stability criterion. |
| Qualification in progress | A current indication that a synchronized input differs from its last qualified state and has not yet satisfied the configured qualification interval. |
| Raw timestamp | The always-running 64-bit monotonic microsecond counter driven by CORE_CLK after functional reset release. |
| Requested state | The combinational or registered OR of currently active authorized response sources before latch policy and permit gating. |
| Reset-held state | A current indication that reset or reset-recovery sequencing is forcing the subject function or output to its reset-safe state. |
| Safe state | A defined state that prevents unintended activation during reset, startup, disabled, inhibited, invalid, unconfigured, or test operation. |
| Saturating counter | A counter that stops at its maximum value and does not wrap. |
| Sticky evidence | Historical evidence set by a qualifying occurrence and retained until its defined authorized clear or applicable reset; disappearance of the active condition does not clear sticky evidence. |
| Transaction sequence | The 11-bit value allocated to an accepted SPI command by advancing a sequence allocator exactly once modulo 2048 at command acceptance. The allocated value becomes the sequence member of the host-reconciliation record only when that same command reaches terminal status. A pre-acceptance abort allocates no value; a post-acceptance response truncation does not cancel the allocated value. |
| Valid CORE_CLK edge | A rising edge satisfying the clock requirements of Section 6.2 after the applicable platform reset condition permits clocked operation. |

Numeric values are unsigned unless explicitly identified as signed. Sensor values, sensor thresholds, and sensor hysteresis operands are signed 32-bit two's-complement quantities. Register addresses are 32-bit byte offsets. Time intervals stated in CORE_CLK cycles are evaluated using valid rising edges.

## 4. System Operating Concept

After valid power, clock, and reset, Dragon Core loads safe volatile defaults, reaches host-interface-ready operation, accepts conforming mapped host transactions, performs enabled monitoring and digital-databus functions, records evidence, reports interrupts and faults, and enforces configured hardware safety supervision without executing on-device software.

The external host may verify device identity and status, apply authorized nondefault volatile configuration, retrieve status and evidence, service watchdog and interrupt functions, and issue permitted commands. Persistent configuration storage, long-term data retention, and aircraft application policy remain external.

The device-side contract supports deterministic external-software initialization and recovery. The host can determine current operating state, read every active configurable value, distinguish current conditions from historical evidence, reconcile the most recent accepted transaction after response loss, retrieve retained event and diagnostic evidence, and reapply nondefault configuration after reset or power loss. No software-facing behavior depends on hidden persistent state inside Dragon Core.

### 4.1 Externally Observable Operating States

| State | Required external behavior |
|---|---|
| RESET_ACTIVE | Functional outputs are held at their safe reset values; normal host commands are not accepted. |
| STARTUP | Reset release, default loading, clock/reset qualification, and deterministic hardware initialization are in progress; externally effective operation remains inhibited. |
| NORMAL | Initialization is complete and every mandatory enabled function is available without an active degraded or faulted condition. |
| DEGRADED | At least one recoverable enabled-function fault is active; unaffected functions continue. |
| FAULTED | A nonrecoverable or designated critical condition is active; required safe responses and evidence preservation apply. |
| TEST_DEBUG | Authorized production-test or bounded engineering behavior is active; operational safety outputs remain inactive. |

`OBSERVATIONAL_MODE`, `HOST_READY`, `INIT_COMPLETE`, `INIT_FAILED`, and `EFFECTIVE_OPERATIONAL_ENABLE` are orthogonal conditions, not additional primary operating states.

The operating-state priority shall be RESET_ACTIVE, FAULTED, STARTUP, DEGRADED, TEST_DEBUG, then NORMAL. A higher-priority active condition shall determine the reported primary state.

## 5. Functional Requirements

### 5.1 System Control and Operating State

| Requirement ID | Requirement |
|---|---|
| **DFC-FUNC-0001** | Dragon Core shall implement one host-visible logical register programming model for configuration, command, status, evidence, and identification access. |
| **DFC-FUNC-0002** | Dragon Core shall initialize every volatile configuration item and hardware-controlled state element to its specified safe reset value without executing software. |
| **DFC-FUNC-0003** | Dragon Core shall retain each active volatile configuration value until an authorized modification, an applicable reset, or loss of operating power. |
| **DFC-FUNC-0004** | Dragon Core shall report successful completion or a definitive rejection reason for every accepted host command. |
| **DFC-FUNC-0005** | Dragon Core shall prevent a rejected, malformed, unsupported, out-of-range, unaligned, unauthorized, or failed host command from modifying the target or unrelated functional state, except for diagnostic evidence explicitly required for the failure. |
| **DFC-FUNC-0006** | Dragon Core shall implement and report the six primary operating states defined in Section 4.1 using the specified priority. |
| **DFC-FUNC-0007** | Dragon Core shall provide independent host-visible current-state readback of `HOST_READY`, `INIT_COMPLETE`, `INIT_FAILED`, `OBSERVATIONAL_MODE`, and `EFFECTIVE_OPERATIONAL_ENABLE`; none of these qualifiers shall require inference from the primary operating-state encoding or from a commanded control value. |
| **DFC-FUNC-0008** | Effective operational enable shall be asserted if and only if `OPERATIONAL_ENABLE` and `INIT_COMPLETE` are asserted, `INIT_FAILED` is deasserted, the primary state is NORMAL or DEGRADED, and both `OBSERVATIONAL_MODE` and TEST_DEBUG are deasserted. |
| **DFC-FUNC-0009** | Dragon Core shall distribute effective operational enable, global interrupt enable, and global event enable through deterministic registered control paths. |
| **DFC-FUNC-0010** | Dragon Core shall keep mandatory functions enabled, permit independent control of optional-function enables, and exclude a disabled optional function from degraded-state determination. |
| **DFC-FUNC-0011** | Dragon Core shall support protected controlled system reset, safety-domain reset, and reset of each eligible module. |
| **DFC-FUNC-0012** | An accepted controlled reset shall report busy state, terminal completion or rejection, last requested scope, and last terminal result. |
| **DFC-FUNC-0013** | A controlled reset request received while another controlled reset is busy shall be rejected without queueing or preemption. |
| **DFC-FUNC-0014** | A new terminal reset result shall dominate a simultaneous request to clear prior terminal reset evidence. |
| **DFC-FUNC-0015** | Dragon Core shall report deterministic ready and fault status for each defined function and aggregate startup, normal, degraded, and faulted status. |
| **DFC-FUNC-0016** | A mandatory-function fault, host-path internal timeout, mandatory startup timeout, or post-initialization loss of mandatory ready shall cause FAULTED. |
| **DFC-FUNC-0017** | An enabled optional-function fault or failure to become ready within its specified enable or reset-recovery interval shall request DEGRADED without disabling unaffected functions. |
| **DFC-FUNC-0018** | Dragon Core shall report each entry into and exit from DEGRADED or FAULTED and shall make each transition eligible for timestamped event recording. |

### 5.2 Interrupts, Time, and Event Evidence

| Requirement ID | Requirement |
|---|---|
| **DFC-FUNC-0019** | Dragon Core shall collect exactly 32 internal interrupt-source positions using the fixed allocation owned by the Architecture Specification. |
| **DFC-FUNC-0020** | Dragon Core shall provide independent enable control, raw-source status, pending-source status, acknowledgement, and clearing for each implemented interrupt source. |
| **DFC-FUNC-0021** | Reserved interrupt-source positions shall remain inactive and shall not assert the host interrupt output. |
| **DFC-FUNC-0022** | Dragon Core shall preserve simultaneous pending conditions without loss of source identity. |
| **DFC-FUNC-0023** | A latched interrupt condition shall remain pending until its source-clearing condition, authorized host clear, or applicable reset occurs. |
| **DFC-FUNC-0024** | A host clear shall affect only the selected clearable interrupt sources and shall not clear unrelated raw, pending, or diagnostic evidence. |
| **DFC-FUNC-0025** | A new qualifying interrupt assertion shall dominate a simultaneous clear of the same source. |
| **DFC-FUNC-0026** | Dragon Core shall provide a continuously operating 64-bit raw timestamp after functional reset release while CORE_CLK remains valid. |
| **DFC-FUNC-0027** | The raw timestamp shall initialize to zero, shall increment once per microsecond, and shall never be host-disabled or host-written. |
| **DFC-FUNC-0028** | The first raw-timestamp increment shall occur on the fiftieth valid CORE_CLK rising edge after synchronized functional reset release; subsequent increments shall occur every fifty valid rising edges. |
| **DFC-FUNC-0029** | Dragon Core shall provide a coherent host snapshot of the complete 64-bit raw timestamp. |
| **DFC-FUNC-0030** | Dragon Core shall permit protected atomic commit of a signed 64-bit correlation offset without changing the raw timestamp. |
| **DFC-FUNC-0031** | When correlation is enabled, the correlated timestamp shall equal raw timestamp plus the active signed offset modulo 2^64; overflow or underflow of the correlation addition shall set host-visible sticky evidence. |
| **DFC-FUNC-0032** | Dragon Core shall identify each committed correlation-offset update with a monotonically incrementing update sequence and shall snapshot raw and correlated time from the same hardware instant. |
| **DFC-FUNC-0033** | All integrated functions requiring time correlation shall use the common raw timestamp unless the Architecture explicitly identifies a host presentation as correlated time. Stored event records shall always contain raw timestamp values. |
| **DFC-FUNC-0034** | Dragon Core shall store exactly 64 complete 128-bit event records. |
| **DFC-FUNC-0035** | Each event record shall contain a 64-bit raw timestamp, a 16-bit event identifier, an 8-bit source identifier, 8 bits of flags, and 32 bits of event-specific data. Numeric allocations and formats are owned by the Architecture Specification. |
| **DFC-FUNC-0036** | Dragon Core shall preserve retained event records from oldest to newest and shall permit coherent inspection and removal by the external host. |
| **DFC-FUNC-0037** | Event retrieval shall not suspend enabled monitoring, databus, interrupt, fault, watchdog, interlock, lost-link, routing, or safety-supervision functions. |
| **DFC-FUNC-0038** | When a new accepted event arrives while all 64 records are occupied, Dragon Core shall overwrite the oldest record, retain the new record, set sticky event-store-overflow status, and increment a saturating event-store-overflow counter. |
| **DFC-FUNC-0039** | The overwrite-oldest policy shall be mandatory and shall not be host-configurable. |
| **DFC-FUNC-0040** | Dragon Core shall support exactly 24 event-producer positions and shall make each producer's source overflow observable through sticky source-overflow evidence and a saturating per-source loss count. |
| **DFC-FUNC-0041** | Dragon Core shall generate a source-overflow diagnostic event for pending producer loss and a distinct event-store-overflow diagnostic event for store overwrite; the store-overflow event shall have higher acceptance priority. |
| **DFC-FUNC-0042** | Multiple unrecorded occurrences of the same overflow class may be coalesced while an overflow report is pending, but the corresponding saturating count shall include every occurrence. |
| **DFC-FUNC-0043** | An internally generated overflow diagnostic record shall not recursively increment an overflow counter or request another overflow diagnostic record solely because it is an overflow record. |
| **DFC-FUNC-0044** | An authorized clear of retained event records shall empty the event store and clear event-store-overflow evidence without modifying unrelated configuration or functional state. |
| **DFC-FUNC-0045** | Dragon Core shall support independent event-source enables while ensuring that safety-critical and overflow evidence designated mandatory by the Architecture remains recordable when global ordinary-event recording is disabled. |

### 5.3 General-Purpose Digital I/O

| Requirement ID | Requirement |
|---|---|
| **DFC-FUNC-0046** | Dragon Core shall provide eight independently configurable digital GPIO channels. |
| **DFC-FUNC-0047** | Each GPIO channel shall support independently selected input or output operation, output value, input qualification, event enables, and interrupt enables. |
| **DFC-FUNC-0048** | A GPIO configured as an input shall not drive its pad; a GPIO configured as an output shall drive only the configured logical value subject to reset and effective-operational gating. |
| **DFC-FUNC-0049** | Dragon Core shall report raw input, synchronized input, qualified input, commanded output, effective output, direction, qualification-in-progress, and enabled retained event evidence independently for each GPIO channel. |
| **DFC-FUNC-0050** | Dragon Core shall support qualified rising-edge, falling-edge, either-edge, active-high-level, and active-low-level GPIO event conditions. |
| **DFC-FUNC-0051** | Each enabled qualifying GPIO event shall be eligible for timestamped event recording and the configured internal interrupt source. |
| **DFC-FUNC-0052** | GPIO behavior shall remain limited to documented digital monitoring, indication, and bounded adaptation; electrical protection and level adaptation remain external as assigned by the PBIO Specification. |

### 5.4 Digital Databus Functions

| Requirement ID | Requirement |
|---|---|
| **DFC-FUNC-0053** | Dragon Core shall provide one ARINC 429 receive function supporting configured low-speed and high-speed operation from a conditioned digital input. |
| **DFC-FUNC-0054** | The ARINC 429 receive function shall recognize complete 32-bit words, validate configured parity and framing, and associate each accepted word with a raw timestamp and sequence value. |
| **DFC-FUNC-0055** | The ARINC 429 receive function shall provide an eight-entry receive queue and shall make the oldest retained word and its metadata available to the host without stopping reception. |
| **DFC-FUNC-0056** | ARINC 429 receive overrun, parity error, framing error, disabled reception, and external-adapter error shall produce defined status and eligible event or interrupt evidence. |
| **DFC-FUNC-0057** | Dragon Core shall provide one ARINC 429 transmit function supporting configured low-speed and high-speed operation through two digital transmit-control outputs. |
| **DFC-FUNC-0058** | The ARINC 429 transmit function shall accept only complete authorized 32-bit-word requests from the host or bounded message router. |
| **DFC-FUNC-0059** | The ARINC 429 transmit function shall provide an eight-entry transmit queue, preserve request order, enforce the configured interword gap, and report completion or rejection. |
| **DFC-FUNC-0060** | ARINC 429 transmit underrun, rejected request, queue overflow, and external-adapter error shall produce defined status and eligible event or interrupt evidence. |
| **DFC-FUNC-0061** | Dragon Core shall provide one Classical CAN controller capable of receiving and transmitting valid CAN 2.0A and CAN 2.0B frames. |
| **DFC-FUNC-0062** | The CAN controller shall support 11-bit and 29-bit identifiers, zero through eight data bytes, data and remote frames, and configured nominal bit rates through 1 megabit per second. |
| **DFC-FUNC-0063** | The CAN controller shall provide independent eight-entry receive and eight-entry transmit queues and shall preserve the order of retained frames within each queue. |
| **DFC-FUNC-0064** | Each accepted CAN receive frame and each completed CAN transmit frame shall be associated with a raw timestamp and sequence value. |
| **DFC-FUNC-0065** | The CAN controller shall maintain and report transmit and receive error counters, error-active, error-passive, and bus-off state in accordance with Classical CAN protocol behavior. |
| **DFC-FUNC-0066** | CAN arbitration loss, protocol error, receive overflow, transmit rejection, bus-off, and external-transceiver error shall produce defined status and eligible event or interrupt evidence; transmission shall remain inhibited in bus-off until a host-commanded or configured standards-conforming recovery completes. |
| **DFC-FUNC-0067** | Dragon Core shall provide one full-duplex UART function with independent receive and transmit paths. |
| **DFC-FUNC-0068** | The UART shall support eight data bits, configurable parity, one or two stop bits, and configured rates through 1 megabit per second. |
| **DFC-FUNC-0069** | The UART shall provide independent sixteen-byte receive and sixteen-byte transmit queues and preserve byte order within each queue. |
| **DFC-FUNC-0070** | UART framing, parity, overrun, underrun, break, queue overflow, and invalid-configuration conditions shall produce defined status and eligible event or interrupt evidence. |
| **DFC-FUNC-0071** | Dragon Core shall provide one bounded databus-message router with exactly five canonical message sources and five canonical message destinations. |
| **DFC-FUNC-0072** | Every canonical message shall be exactly 192 bits and shall represent a payload length from zero through eight bytes together with source, type, flags, metadata, payload, timestamp, and sequence information defined by the Architecture Specification. |
| **DFC-FUNC-0073** | The message router shall accept an authorized message from any enabled source and may replicate one accepted message to one or more authorized destinations. |
| **DFC-FUNC-0074** | Every routing decision shall depend only on committed routing configuration, the canonical message, source identity, filter comparison, and the fixed source-to-destination authorization matrix. |
| **DFC-FUNC-0075** | The router shall provide five ingress entries and four complete-message queue entries per destination and shall prevent partial-message visibility. |
| **DFC-FUNC-0076** | A full destination queue shall apply the Architecture-defined backpressure or drop behavior without corrupting another destination copy; every dropped copy shall increment a saturating loss count and set sticky evidence. |
| **DFC-FUNC-0077** | The host shall be able to independently disable each configurable message-routing path and inspect active committed routing configuration and routing status. |
| **DFC-FUNC-0078** | Databus receive, transmit, timestamp, event, and routing functions shall operate concurrently subject to their finite queues and defined arbitration. |

### 5.5 Monitoring and Health Functions

| Requirement ID | Requirement |
|---|---|
| **DFC-FUNC-0079** | Dragon Core shall measure rotor speed from one conditioned pulse input over 0 through 1,000 revolutions per minute. |
| **DFC-FUNC-0080** | Rotor speed shall be represented in whole revolutions per minute and compared with independently configurable low and high thresholds and hysteresis. |
| **DFC-FUNC-0081** | Dragon Core shall measure engine speed from one conditioned pulse input over 0 through 20,000 revolutions per minute. |
| **DFC-FUNC-0082** | Engine speed shall be represented in whole revolutions per minute and compared with independently configurable low and high thresholds and hysteresis. |
| **DFC-FUNC-0083** | Rotor and engine monitoring shall support configurable pulses-per-revolution, input qualification, no-pulse timeout, validity, and enabled low, high, timeout, recovery, event, and interrupt behavior. |
| **DFC-FUNC-0084** | Dragon Core shall provide two additional independent general-purpose pulse or frequency measurement channels. |
| **DFC-FUNC-0085** | Each general-purpose channel shall measure 0.5 hertz through 100 kilohertz and represent current frequency, thresholds, and hysteresis as unsigned Q17.15 hertz values. |
| **DFC-FUNC-0086** | Each general-purpose channel shall report validity, current measurement, low, high, timeout, saturation, and recovery state and shall support enabled events and interrupts for those conditions. |
| **DFC-FUNC-0087** | Dragon Core shall provide exactly two sampled-sensor monitor channels. |
| **DFC-FUNC-0088** | Each sensor update shall contain a signed 32-bit two's-complement value, validity indication, 7-bit source value, and 24-bit sequence value. |
| **DFC-FUNC-0089** | Each sensor channel shall accept atomic staged updates from the external host or an authorized routed-message source and shall reject malformed, unauthorized, or incomplete updates without changing the active sample. |
| **DFC-FUNC-0090** | If a host update and a routed update for the same sensor channel become eligible in the same CORE_CLK cycle, the host update shall take priority and the routed update shall remain pending or be rejected with loss evidence as defined by the Architecture. |
| **DFC-FUNC-0091** | A committed sensor update shall atomically replace value, validity, source, sequence, and age state; age shall restart at zero on that commit. |
| **DFC-FUNC-0092** | Each sensor channel shall compare its signed value against signed low and high thresholds with signed hysteresis and shall report valid, invalid, stale, low, high, and recovery state. |
| **DFC-FUNC-0093** | Each sensor channel shall maintain a saturating age in milliseconds and shall assert stale when the configured nonzero maximum age is exceeded; maximum age zero shall disable stale detection. |
| **DFC-FUNC-0094** | Low, high, stale, and invalid sensor conditions shall have independent event and interrupt enables. |
| **DFC-FUNC-0095** | Dragon Core shall monitor eight independent conditioned digital health or discrete inputs. |
| **DFC-FUNC-0096** | Each health input shall support polarity, qualification, asserted, deasserted, transition, sticky, recovery, event, interrupt, and optional external-fault-source behavior. |
| **DFC-FUNC-0097** | Dragon Core shall report per-input raw, synchronized, qualified, qualification-in-progress, active, sticky asserted, sticky recovered, and sticky qualification-failure state, together with the current aggregate health-fault indication; each reported concept shall be independently distinguishable. |

### 5.6 Hardware Safety-Supervision Functions

| Requirement ID | Requirement |
|---|---|
| **DFC-FUNC-0098** | Dragon Core shall provide one hardware watchdog that supervises a configured external service source without software executing inside Dragon Core. |
| **DFC-FUNC-0099** | The watchdog shall support protected enable, minimum and maximum service-window limits, timeout, service-key validation, recovery, event, interrupt, fault, and authorized logical safety-response configuration. |
| **DFC-FUNC-0100** | An early, late, missing, or invalid watchdog service shall produce the separately defined evidence and only the responses authorized for that condition. |
| **DFC-FUNC-0101** | Dragon Core shall provide centralized collection and latching for the fixed 17 implemented fault sources and shall keep reserved fault-source positions inactive. |
| **DFC-FUNC-0102** | Each fault source shall have a fixed classification, recoverability property, priority, event behavior, interrupt behavior, and eligible safety response defined by the Architecture Specification. |
| **DFC-FUNC-0103** | Dragon Core shall report active, sticky, recoverable, nonrecoverable, primary, response-pending, and event-pending fault evidence without losing simultaneous source identity. |
| **DFC-FUNC-0104** | Dragon Core shall provide eight independently configurable interlock expressions, each containing four terms selected from the finite Architecture-defined term-source allocation. |
| **DFC-FUNC-0105** | Each interlock expression shall support only the finite operators and guard relationships defined by the Architecture and shall be activated only by an atomic protected commit of a valid staged definition. |
| **DFC-FUNC-0106** | An invalid, incomplete, or unauthorized staged interlock definition shall be rejected without modifying the active expression. |
| **DFC-FUNC-0107** | An enabled unsatisfied interlock shall inhibit every guarded action assigned to it and shall produce active, sticky, transition, event, interrupt, and authorized response evidence. |
| **DFC-FUNC-0108** | Dragon Core shall provide eight independently configurable lost-link monitors using only the finite activity-source allocation defined by the Architecture Specification. |
| **DFC-FUNC-0109** | Each lost-link monitor shall support protected enable, activity qualification, timeout, recovery interval, event, interrupt, fault, and authorized logical safety-response configuration. |
| **DFC-FUNC-0110** | Each enabled lost-link monitor shall assert loss after the configured absence interval and shall report active, sticky, recovered, source, elapsed-time, and response evidence. |
| **DFC-FUNC-0111** | Dragon Core shall provide four independently controlled low-voltage logical safety-output channels. |
| **DFC-FUNC-0112** | A logical safety output shall become active only from an active authorized hardware response source while its channel is enabled, effective operation is permitted, global inhibit is inactive, and every applicable interlock and fault inhibit is satisfied. |
| **DFC-FUNC-0113** | Each logical safety output shall independently report requested state, latched-request state, commanded state, effective state, channel-disabled state, controller-disabled state, global-inhibit state, observational-inhibit state, test-inhibit state, interlock-inhibit state, fault-inhibit state, and reset-held state; an aggregate inhibited indication shall not replace any required cause indication. |
| **DFC-FUNC-0114** | The host shall configure only response authorization, channel policy, polarity, latch policy, recovery policy, and clearing behavior; no host-visible register shall directly command a logical safety output active. |
| **DFC-FUNC-0115** | The safety-response authorization mask shall contain 32 positions corresponding to the fixed Architecture-defined four-lane by eight-source mapping; writes that set any reserved authorization position shall be rejected. |
| **DFC-FUNC-0116** | Simultaneous authorized safety requests for the same channel shall be combined by requested response action without allowing one source to suppress another active source. |

### 5.7 Bounded User Logic and User Routing

| Requirement ID | Requirement |
|---|---|
| **DFC-FUNC-0117** | Dragon Core shall include one bounded mask-defined User Logic Island whose structure is fixed before fabrication and cannot execute instructions or become field-programmable. |
| **DFC-FUNC-0118** | The Revision A User Logic Island functional profile shall be inert: it shall generate no externally routed output message, shall hold every user output pad inactive and not driven, and shall reject every nonzero functional-parameter value. |
| **DFC-FUNC-0119** | The inert User Logic Island may capture its four synchronized user inputs and may exchange diagnostic data through two four-word mailboxes without producing an operational action. |
| **DFC-FUNC-0120** | Dragon Core shall report User Logic Island enable, reset, health, mailbox, rejected-parameter, and violation status. |
| **DFC-FUNC-0121** | Dragon Core shall provide finite user-configurable signal routing only between exact Architecture-defined source and destination identifiers. |
| **DFC-FUNC-0122** | A user route shall become active only after protected validation and atomic commit against the fixed source-to-destination authorization matrix. |
| **DFC-FUNC-0123** | User routing shall not reach logical safety outputs, protocol transmitters, clocks, resets, protected writes, host transport control, production-test authorization, or arbitrary internal signals. |
| **DFC-FUNC-0124** | Disabled, invalid, conflicting, or uncommitted user routes shall contribute no destination action. |
| **DFC-FUNC-0125** | Dragon Core shall report active user routes, rejected staging or commit, source conflict, destination conflict, and routing-violation evidence and shall make each protected configuration result eligible for a timestamped event. |

### 5.8 Top-Level Integration and Diagnostics

| Requirement ID | Requirement |
|---|---|
| **DFC-FUNC-0126** | RTL-024 shall present the complete technology-independent Dragon Core logical wrapper and shall integrate the functions included by `CHTR-SCOPE-001` through `CHTR-SCOPE-006`. |
| **DFC-FUNC-0127** | Dragon Core shall provide one centralized logical 512-word by 32-bit shared-buffer service allocated by `PBIO-MEM-001` through `PBIO-MEM-004` while preserving each client's externally visible queue, mailbox, loss, and ordering behavior. |
| **DFC-FUNC-0128** | The event store allocated by `PBIO-MEM-005` shall remain functionally independent of the centralized shared-buffer service. |
| **DFC-FUNC-0129** | Dragon Core shall drive every externally visible output to its defined safe state until its function is valid and permitted to act. |
| **DFC-FUNC-0130** | Dragon Core shall expose host-visible current status and sticky historical evidence for every Architecture-defined detected fault or error in the host, GPIO, databus, pulse, sampled-sensor, health, watchdog, fault-manager, interlock, lost-link, logical safety-output, user-I/O, user-routing, clock, reset, shared-buffer, event, and production-test functions. |
| **DFC-FUNC-0131** | Dragon Core shall distinguish active condition, sticky historical evidence, and saturating count wherever those concepts are specified and shall not clear one as an undocumented side effect of reading another. |
| **DFC-FUNC-0132** | Every externally observable reserved state, unused interface, disabled function, invalid encoding, timeout, overflow, and simultaneous command or event shall have deterministic behavior defined by this SRS or its designated downstream normative owner. |
| **DFC-FUNC-0133** | Host-transport diagnostics shall independently report sticky invalid-opcode, invalid-length, unaligned-address, invalid-address, access-error, protected-write-failure, CRC-error, internal-timeout, endpoint-error, pre-acceptance-abort, and post-acceptance-response-truncation evidence and shall provide saturating counts for CRC errors, an aggregate of aborts and truncations, internal timeouts, and an aggregate of invalid-opcode, invalid-length, unaligned-address, invalid-address, access-error, protected-write-failure, and endpoint-error occurrences. |
| **DFC-FUNC-0134** | Every finite queue or mailbox serviced by the host shall expose its applicable current empty, full, occupancy, or busy state and persistent overflow, underflow, rejected-access, and dropped-data evidence. Each such loss class and each loss at an internal ingress slot, event-pending slot, event store, or shared-buffer client shall have a saturating count that identifies the affected host-visible resource or internal source. |
| **DFC-FUNC-0135** | Clock and reset diagnostics shall retain host-visible evidence of every Architecture-defined detectable invalid-clock, lost-clock, illegal-reset, reset-timeout, reset-rejection, and reset-recovery failure condition that permits subsequent host reporting. |
| **DFC-FUNC-0136** | Production-test diagnostics shall independently report current authorization, qualified active state, busy state, terminal completion, terminal rejection reason, unsafe-command rejection, safety blocking, deauthorization abort, and injected-versus-natural fault evidence; rejected or aborted test commands shall set sticky evidence and increment a saturating rejection-or-abort count. |
| **DFC-FUNC-0137** | A diagnostic clear shall affect only the explicitly selected clearable evidence or whole counter and shall not clear an active source, an unrelated diagnostic class, retained event records, or the host-reconciliation record. |
| **DFC-FUNC-0138** | When the same occurrence contributes to module-local evidence, aggregate fault status, interrupt status, and event evidence, each reporting path shall preserve the same source identity and shall remain independently serviceable according to its defined clear behavior. |

## 6. External Interface Requirements

### 6.1 Logical Pad Population

The Dragon Core logical wrapper has exactly 44 functional pad positions and three fixed production-test pad positions. Physical cells, package pins, voltage domains, and placement are owned by the applicable platform and future ASIC Integration Specification.

| Functional interface | Pad positions | Direction at logical wrapper |
|---|---:|---|
| CORE_CLK | 1 | Input |
| SPI host transport | 4 | SCLK, CS_N, MOSI inputs; MISO tri-stated output |
| Host interrupt | 1 | Output |
| GPIO | 8 | Independently bidirectional |
| ARINC 429 | 5 | One receive input, two transmit-control outputs, receive-adapter-error input, transmit-adapter-error input |
| Classical CAN | 3 | Receive input, transmit output, transceiver-error input |
| UART | 2 | Receive input, transmit output |
| Rotor, engine, and general pulse | 4 | Inputs |
| Health/discrete | 8 | Inputs |
| Logical safety outputs | 4 | Outputs |
| User logic | 4 | Bidirectional-capable positions held input/high-impedance by the Revision A inert profile |
| **Functional total** | **44** | |

| Fixed production-test interface | Pad positions | Direction at logical wrapper |
|---|---:|---|
| TEST_ENABLE | 1 | Input |
| TEST_CLOCK | 1 | Input |
| TEST_DATA | 1 | Bidirectional, high impedance unless authorized |
| **Production-test total** | **3** | |

| Requirement ID | Requirement |
|---|---|
| **DFC-INTF-0001** | The logical wrapper shall expose exactly the 44 functional and three fixed production-test pad positions enumerated in Section 6.1. |
| **DFC-INTF-0002** | Functional reset shall enter the logical wrapper as an internal platform-wrapper input and shall not consume an external configurable pad position. |
| **DFC-INTF-0003** | Every input pad signal other than CORE_CLK and TEST_CLOCK shall be treated as asynchronous to its destination clock domain and shall be accepted only through the synchronization or protocol mechanism defined by the Architecture Specification. |
| **DFC-INTF-0004** | Every output and bidirectional output-enable shall assume its defined safe value during reset, startup, disable, invalid configuration, and unauthorized test operation. |

### 6.2 Clock and Reset Interface

| Requirement ID | Requirement |
|---|---|
| **DFC-INTF-0005** | Dragon Core shall accept one free-running CORE_CLK input at 50.000 MHz nominal with plus or minus 100 ppm frequency tolerance. |
| **DFC-INTF-0006** | CORE_CLK duty cycle shall be 45 percent through 55 percent, peak-to-peak cycle-to-cycle jitter shall not exceed 1.0 ns, and 20-to-80-percent transition time shall not exceed 2.0 ns at the logical input boundary. |
| **DFC-INTF-0007** | The platform reset input shall assert functional reset asynchronously and shall release CORE_CLK-domain functional logic only after at least four consecutive valid CORE_CLK rising edges. |
| **DFC-INTF-0008** | Reset assertion or loss of valid clock shall place every external output in its defined safe state without requiring a host command. |
| **DFC-INTF-0009** | On the first CORE_CLK edge following synchronized functional reset release, Dragon Core shall enter STARTUP, initialize startup sequencing and status, and hold effective operational enable inactive; startup qualification shall begin on the next edge. |
| **DFC-INTF-0010** | Ordinary power-up and functional reset shall not depend on staggered per-module reset release or on executable initialization software. |

### 6.3 SPI Host Transport

| Requirement ID | Requirement |
|---|---|
| **DFC-INTF-0011** | Production host transactions shall use a conforming external SPI controller connected to Dragon Core as an SPI peripheral; VisionFive 2 is the selected FPGA-validation host but is not a production-host requirement. |
| **DFC-INTF-0012** | The SPI interface shall consist of SCLK, active-low CS_N, MOSI, and MISO, shall use SPI Mode 0 with bytes and multibyte fields transmitted most-significant bit and most-significant byte first, and shall carry each complete command and response within one asserted CS_N interval. |
| **DFC-INTF-0013** | Dragon Core shall accept SPI SCLK from 100 kHz through 10 MHz while CORE_CLK is valid. |
| **DFC-INTF-0014** | MISO shall be high impedance whenever CS_N is inactive and before the defined response phase. |
| **DFC-INTF-0015** | After SPI reset release, CS_N shall remain inactive and SCLK shall remain low for at least 1 microsecond; Dragon Core shall not accept a frame before that quiet interval has elapsed. |
| **DFC-INTF-0016** | CS_N shall be asserted for at least 50 ns before the first SCLK rising edge of a command. |
| **DFC-INTF-0017** | READ shall use opcode `0x01`; WRITE shall use opcode `0x02`; every other opcode shall be rejected as invalid. |
| **DFC-INTF-0018** | A command shall contain, in order, one opcode byte, one 32-bit byte address, one count-minus-one byte, zero or more write-data words when applicable, and one 16-bit command CRC. |
| **DFC-INTF-0019** | Count-minus-one values `0x00` through `0x0F` shall represent one through sixteen 32-bit words; bits 7:4 of the count byte shall be zero, and a nonzero upper nibble shall be rejected as invalid length. |
| **DFC-INTF-0020** | A READ command shall contain no write-data words and shall be eight bytes; a WRITE command shall contain exactly the selected number of four-byte data words and shall therefore be eight plus four times the word count bytes. |
| **DFC-INTF-0021** | The first word shall use the command address and each subsequent word shall use the preceding byte address plus four; every address shall be aligned to four bytes. |
| **DFC-INTF-0022** | Command and response integrity shall use CRC-16/CCITT-FALSE with polynomial `0x1021`, initial value `0xFFFF`, no input or output reflection, and XOR-out `0x0000`. |
| **DFC-INTF-0023** | Command CRC shall cover every command byte preceding the CRC; response CRC shall cover the response marker through the final response data byte and shall exclude wait-fill bytes and the response CRC itself. |
| **DFC-INTF-0024** | A response shall contain zero through two `0x00` wait-fill bytes, marker `0xA5`, one status byte, one completed-word-count byte, one reserved-zero byte, zero or more read-data words, and one 16-bit response CRC. |
| **DFC-INTF-0025** | A READ response shall contain exactly the completed-word-count number of read-data words, including a partial result when a later read word fails; every WRITE response shall contain no read-data words. |
| **DFC-INTF-0026** | A single-word WRITE command shall be 12 bytes and its non-fill response shall be 6 bytes; a single-word READ command shall be 8 bytes and its non-fill response shall be 10 bytes. |
| **DFC-INTF-0027** | The response status values shall be: `0x00` success, `0x01` busy, `0x02` invalid opcode, `0x03` invalid length or count, `0x04` unaligned address, `0x05` invalid address, `0x06` access error, `0x07` protected-write failure, `0x08` CRC error, `0x09` internal timeout, and `0x0A` endpoint error; values `0x0B` through `0xFF` are reserved and shall not be transmitted. |
| **DFC-INTF-0028** | The completed-word-count byte shall report the number of words successfully completed before the reported status and shall be zero for a rejection that occurs before any word completes. |
| **DFC-INTF-0029** | A command shall be accepted only after its complete command CRC has been received and validated while CS_N remains asserted. |
| **DFC-INTF-0030** | Deassertion of CS_N before command acceptance shall generate no internal register request and no target-register side effect, shall clear any transaction-scoped protected-write authorization, and shall update sticky abort evidence and a saturating abort counter available through a later valid transaction. |
| **DFC-INTF-0031** | A pre-acceptance abort shall not attempt to return an abort response within the aborted frame and shall not replace the last-result fields for the most recent accepted command. |
| **DFC-INTF-0032** | Deassertion of CS_N after command acceptance may truncate the response but shall not roll back a completed write; response truncation shall set sticky truncation or abort evidence without changing the accepted command's terminal result. |
| **DFC-INTF-0033** | A multiword command shall be non-atomic: words shall execute in increasing address order, execution shall stop at the first failing word, earlier completed words shall remain committed, and later words shall not execute. |
| **DFC-INTF-0034** | Register-defined staging and commit operations shall remain the only mechanism for atomic activation of a multiregister configuration. |
| **DFC-INTF-0035** | Each accepted SPI command shall produce at most one target request per word and exactly one definitive transaction status; an internal timeout shall prevent a later untracked target write from becoming externally effective. |
| **DFC-INTF-0036** | The host interface shall expose ready, busy, the complete host-reconciliation record, CRC error, pre-acceptance abort, response truncation, timeout, invalid address, access error, and protected-write-failure evidence. |

### 6.4 Host Interrupt, GPIO, and User I/O

| Requirement ID | Requirement |
|---|---|
| **DFC-INTF-0037** | Dragon Core shall provide one active-low level-sensitive host interrupt output that asserts while at least one enabled interrupt source is pending. |
| **DFC-INTF-0038** | The host interrupt output shall deassert only after every enabled pending source is cleared or disabled and shall be suitable for synchronization by the external host. |
| **DFC-INTF-0039** | The host-visible interface shall report the complete 32-bit pending-source bitmap and the Architecture-defined encoded primary pending source. |
| **DFC-INTF-0040** | Dragon Core shall provide eight bidirectional GPIO logical interfaces with independent data input, data output, and output-enable behavior. |
| **DFC-INTF-0041** | GPIO pads shall be high impedance during reset and whenever their channel is not configured and permitted as an output. |
| **DFC-INTF-0042** | Dragon Core shall provide four bidirectional-capable user logical I/O positions; Revision A shall hold their outputs inactive and their output enables deasserted. |

### 6.5 Databus External Interfaces

| Requirement ID | Requirement |
|---|---|
| **DFC-INTF-0043** | The ARINC 429 receive interface shall accept one conditioned digital low-speed or high-speed bit stream from an external compliant line receiver. |
| **DFC-INTF-0044** | The ARINC 429 transmit interface shall produce two mutually exclusive digital control outputs with configured low-speed or high-speed timing suitable for an external compliant line driver. |
| **DFC-INTF-0045** | Separate active-high receive-adapter-error and transmit-adapter-error inputs shall report external ARINC adapter faults without being interpreted as ARINC line levels. |
| **DFC-INTF-0046** | The CAN interface shall provide one receive input, one transmit output, and one active-high external-transceiver-error input for connection to an external Classical CAN transceiver. |
| **DFC-INTF-0047** | CAN transmit shall assume the recessive logical state during reset, disable, invalid configuration, and bus-off unless Classical CAN protocol recovery explicitly requires otherwise. |
| **DFC-INTF-0048** | The UART interface shall provide one receive input and one transmit output; UART transmit shall be idle high during reset, disable, and invalid configuration. |
| **DFC-INTF-0049** | External ARINC electrical line receivers and drivers, CAN transceiver and termination, and UART voltage conversion or isolation shall remain outside Dragon Core as assigned by the PBIO Specification. |

### 6.6 Monitoring, Health, and Safety Interfaces

| Requirement ID | Requirement |
|---|---|
| **DFC-INTF-0050** | Dragon Core shall provide dedicated conditioned digital inputs for rotor speed, engine speed, and two general-purpose pulse or frequency sources. |
| **DFC-INTF-0051** | Dragon Core shall provide eight conditioned digital health or aircraft-discrete inputs. |
| **DFC-INTF-0052** | Sampled sensor values shall enter only through the mapped host interface or an authorized canonical message path; analog acquisition, conversion, calibration, and unit conversion remain external. |
| **DFC-INTF-0053** | Dragon Core shall provide four low-voltage logical safety-output interfaces for connection to external safety-driver circuitry. |
| **DFC-INTF-0054** | Every logical safety-output pad shall be inactive during reset, startup, channel disable, global inhibit, observational mode, TEST_DEBUG, and every production-test operation. |
| **DFC-INTF-0055** | External circuitry shall own power switching, isolation, protection, load drive, and final aircraft-energy control; a Dragon Core logical safety output shall not be connected directly to an aircraft energy load. |

### 6.7 Production-Test Interface

| Requirement ID | Requirement |
|---|---|
| **DFC-INTF-0056** | The production-test interface shall use fixed TEST_ENABLE, TEST_CLOCK, and bidirectional TEST_DATA pads and shall not consume a functional pad position. |
| **DFC-INTF-0057** | TEST_DATA shall remain high impedance unless physical test authorization is qualified and the test protocol is in a defined output phase. |
| **DFC-INTF-0058** | Production-test operation shall be bounded to identification, status, a 256-bit diagnostic capture vector, controlled serial shift, eight internal or fixture-safe loopback selections, and permitted fault-injection observations. |
| **DFC-INTF-0059** | Production-test operation shall not activate a logical safety output, bypass an interlock or protected state, modify protected functional configuration, or create an undocumented functional interface. |
| **DFC-INTF-0060** | Every unauthorized, malformed, reserved, busy, or unsafe production-test command shall be rejected with host-visible diagnostic evidence and no prohibited side effect. |

### 6.8 Host Transaction Reconciliation

| Requirement ID | Requirement |
|---|---|
| **DFC-INTF-0061** | One host read command spanning the host-reconciliation registers shall return one coherent snapshot of the preceding terminal accepted command; execution of that read command shall not replace any member of the returned snapshot until every requested reconciliation word has been captured for the response. |
| **DFC-INTF-0062** | The transaction-sequence allocator shall reset to zero on functional reset, shall allocate sequence one to the first accepted command, shall then advance exactly once modulo 2048 for each later accepted command, and shall remain unchanged by a pre-acceptance abort. The sequence member and every other member of the host-reconciliation record shall be replaced atomically only when the identified accepted command reaches terminal status. |

## 7. Configuration and Protection Requirements

| Requirement ID | Requirement |
|---|---|
| **DFC-CONF-0001** | The external host shall be able to read every implemented host-readable configuration field and the effective active value used by hardware. |
| **DFC-CONF-0002** | Every writable configuration field shall define a reset value, legal values or range, reserved-value behavior, validation point, readback behavior, and effect of enable, disable, reset, and commit. |
| **DFC-CONF-0003** | Every unimplemented register address shall return invalid-address status with no functional side effect. |
| **DFC-CONF-0004** | Reserved register fields shall read zero unless the Register Map explicitly defines a constant value, and a write containing a one in a reserved field shall be rejected without modifying any field in that register. |
| **DFC-CONF-0005** | A write to a read-only field or register shall return access error and shall not modify hardware-owned state. |
| **DFC-CONF-0006** | Dragon Core shall provide independent configuration and enable control for each optional communication, monitoring, event, interrupt, safety-supervision, routing, and bounded-user function identified herein. |
| **DFC-CONF-0007** | Dragon Core shall provide independent enable masks for event and interrupt subconditions wherever a function has more than one qualifying subcondition. |
| **DFC-CONF-0008** | A disabled function shall assume its specified safe output state, contribute no new ordinary event or interrupt request, and retain only the status or evidence explicitly designated to survive disable. |
| **DFC-CONF-0009** | Active configuration shall be volatile; the external host shall own persistence and reapplication of nondefault values after reset or power loss. |
| **DFC-CONF-0010** | Before authorized nondefault configuration is committed, Dragon Core shall operate only with the safe reset configuration defined by the Register Map. |
| **DFC-CONF-0011** | Safety, interlock, routing, test, debug, pad-control, controlled-reset, timestamp-correlation, fault-response, and other privileged writes designated by the Register Map shall require the protected-write authorization sequence. |
| **DFC-CONF-0012** | Protected-write authorization shall expire after the Register Map-defined accepted transaction count or timeout, shall be consumed as specified, and shall never survive any reset. |
| **DFC-CONF-0013** | A pre-acceptance SPI abort shall clear transaction-scoped protected-write authorization; a post-acceptance response truncation shall not undo an authorization already consumed by the accepted command. |
| **DFC-CONF-0014** | A protected write attempted without valid authorization shall return protected-write failure and shall not modify the target. |
| **DFC-CONF-0015** | Multiregister interlock, route, sensor-update, mailbox, transmit-entry, timestamp-correlation, and other staged configurations shall not become active until their explicit commit or push command is accepted. |
| **DFC-CONF-0016** | A failed or rejected staged commit shall preserve the previously active configuration and shall report the first applicable validation error. |
| **DFC-CONF-0017** | A successful staged commit shall activate all fields in that staged object atomically at one defined CORE_CLK update. |
| **DFC-CONF-0018** | Dragon Core shall reject an unsupported safety-response encoding or a safety-authorization mask containing any reserved source position. |
| **DFC-CONF-0019** | Dragon Core shall reject an invalid interlock term, operator, guard target, or self-conflicting expression. |
| **DFC-CONF-0020** | Dragon Core shall reject a message route or user signal route not present in the Architecture-defined authorization matrix. |
| **DFC-CONF-0021** | Dragon Core shall reject a payload length greater than eight, an undefined canonical message type, an undefined source or destination, or reserved canonical flags. |
| **DFC-CONF-0022** | Dragon Core shall reject invalid ARINC speed, parity, or interword-gap configuration. |
| **DFC-CONF-0023** | Dragon Core shall reject CAN timing values that cannot produce a valid configured bit time and illegal combinations of identifier type, frame type, data length, loopback, listen-only, or recovery mode. |
| **DFC-CONF-0024** | Dragon Core shall reject a UART divisor or parity and stop-bit combination that cannot produce the specified frame format and rate. |
| **DFC-CONF-0025** | Dragon Core shall reject threshold and hysteresis configurations whose signed or unsigned ordering constraints cannot be satisfied by the applicable monitor. |
| **DFC-CONF-0026** | Dragon Core shall reject zero pulses-per-revolution while the corresponding RPM monitor is enabled and shall reject timeout or qualification values outside the implemented range. |
| **DFC-CONF-0027** | Whole-value saturating counters exposed for host clearing shall ignore a write of `0x00000000`, shall clear entirely on a write of `0xFFFFFFFF`, and shall reject every other written value with access error. |
| **DFC-CONF-0028** | A whole-counter clear shall generate one clear action for the counter and shall not be interpreted as a bitwise clear mask. |
| **DFC-CONF-0029** | True source masks and latched source-status masks designated W1C shall clear only written-one positions; a new qualifying set shall dominate a simultaneous clear of the same position. |
| **DFC-CONF-0030** | A read shall not clear, pop, acknowledge, commit, or otherwise modify state unless the Register Map explicitly defines that read side effect. |
| **DFC-CONF-0031** | Snapshot, pop, clear, push, commit, service, and reset actions shall use explicit command fields and shall report rejection when issued in an invalid state. |
| **DFC-CONF-0032** | Configuration and status readback shall distinguish staged, active, commanded, effective, raw, sticky, and pending values wherever more than one of those values exists. |
| **DFC-CONF-0033** | No configuration mechanism shall alter fabricated mask logic, create a new route endpoint, widen a bounded resource, or expose an unspecified internal signal. |
| **DFC-CONF-0034** | The raw timestamp enable shall be read as constant one or represented as reserved; software shall have no means to stop the raw timestamp after reset release. |
| **DFC-CONF-0035** | Event overwrite-oldest behavior shall be constant and shall not be represented as a writable policy control. |

## 8. Performance and Timing Requirements

| Requirement ID | Requirement |
|---|---|
| **DFC-PERF-0001** | Dragon Core shall assert HOST_READY no later than 1,024 CORE_CLK cycles after synchronized functional reset release when host-interface infrastructure is operational. |
| **DFC-PERF-0002** | Mandatory initialization shall terminate no later than 499,000 CORE_CLK cycles after synchronized functional reset release by asserting either INIT_COMPLETE or INIT_FAILED; INIT_FAILED shall cause FAULTED. |
| **DFC-PERF-0003** | An accepted controlled reset shall assert its complete scope for at least four full CORE_CLK cycles, shall require two consecutive ready cycles after release, and shall produce a terminal result within 1,024 CORE_CLK cycles. |
| **DFC-PERF-0004** | The raw timestamp resolution shall be exactly one microsecond at nominal 50 MHz CORE_CLK and its 64-bit value shall not wrap for at least 500,000 years. |
| **DFC-PERF-0005** | A coherent raw-timestamp snapshot shall capture all 64 bits from one hardware instant and shall be available to the host without stopping the counter. |
| **DFC-PERF-0006** | The SPI interface shall sustain error-free single-register reads and writes at 10 MHz SCLK. |
| **DFC-PERF-0007** | At 100 kHz SCLK, a valid single-word SPI command shall complete with its full definitive response CRC within 1.6 ms of CS_N assertion, including no more than two wait-fill bytes. |
| **DFC-PERF-0008** | A target word accepted by the internal register endpoint shall produce completion or internal-timeout status within eight CORE_CLK cycles, and the complete SPI response shall remain within DFC-PERF-0007. |
| **DFC-PERF-0009** | Each event rate within the Architecture-defined finite producer and arbitration acceptance limits shall be stored without loss until all 64 event records are occupied. |
| **DFC-PERF-0010** | Event retrieval, recording, and overflow handling shall not suspend an enabled independent monitoring, databus, interrupt, fault, interlock, watchdog, lost-link, routing, or safety-output function. |
| **DFC-PERF-0011** | All enabled hardware monitoring channels shall operate concurrently at their specified sample or edge-processing rates. |
| **DFC-PERF-0012** | Rotor and engine speed shall be reported with 1 RPM resolution and plus or minus 1 percent of reading accuracy over their specified ranges for conforming conditioned inputs. |
| **DFC-PERF-0013** | Each general pulse channel shall meet plus or minus 1 percent frequency accuracy over 0.5 Hz through 100 kHz for conforming conditioned inputs. |
| **DFC-PERF-0014** | Initial acquisition of a pulse or frequency input may require one complete input period plus 100 ms; after acquisition, host-visible status shall refresh at least every 100 ms and whenever a new independent estimate becomes available. |
| **DFC-PERF-0015** | Rotor, engine, and general pulse valid results shall update no later than 100 ms after the applicable measurement interval completes. |
| **DFC-PERF-0016** | A new valid sampled-sensor update shall become host-visible and participate in threshold evaluation no later than one CORE_CLK cycle after its atomic commit. |
| **DFC-PERF-0017** | A threshold violation shall be detected no later than one applicable measurement-update interval after a valid violating value becomes available. |
| **DFC-PERF-0018** | Each conditioned GPIO, health, discrete, rotor, engine, or pulse input shall support qualification from disabled through 100 ms with the exact representable step defined by the Register Map. |
| **DFC-PERF-0019** | An enabled internal interrupt source shall cause the aggregated host interrupt output to assert no later than 20 microseconds after the source becomes pending. |
| **DFC-PERF-0020** | The host interrupt output shall deassert no later than 20 microseconds after the last enabled pending source is cleared or disabled. |
| **DFC-PERF-0021** | An authorized hardware safety response shall begin no later than 100 microseconds after its qualifying synchronized and qualified condition becomes active, excluding any explicitly configured qualification interval. |
| **DFC-PERF-0022** | ARINC 429 receive and transmit, CAN, UART, message routing, monitoring, event recording, interrupt handling, and host access shall operate concurrently subject only to finite queue availability and defined arbitration. |
| **DFC-PERF-0023** | The centralized shared-buffer service shall not expose a partial entry and shall preserve the externally specified capacity, order, and loss behavior of every client queue or mailbox. |
| **DFC-PERF-0024** | A shared-buffer client request operating without a fault shall receive a completion response within eight CORE_CLK cycles of acceptance. |
| **DFC-PERF-0025** | A continuous requester shall not permanently starve another continuously eligible shared-buffer client. |
| **DFC-PERF-0026** | Host status retrieval shall not interrupt normal monitoring or change hardware-owned state except through an explicitly commanded side effect. |

## 9. Safety Requirements

| Requirement ID | Requirement |
|---|---|
| **DFC-SAFE-0001** | Dragon Core shall continue configured watchdog, fault, interlock, lost-link, event, and logical safety-output supervision without continuous host participation after valid configuration. |
| **DFC-SAFE-0002** | RESET_ACTIVE, STARTUP, INIT_FAILED, global inhibit, OBSERVATIONAL_MODE, TEST_DEBUG, and production-test operation shall force every logical safety output inactive; disabling an individual safety channel shall force that channel inactive. |
| **DFC-SAFE-0003** | No production-test or debug exception shall permit a logical safety-output test indication at an external safety-output pad. |
| **DFC-SAFE-0004** | No host command, user-logic path, message route, signal route, debug path, test path, wrapper path, or platform resource shall bypass an enabled interlock, active inhibit, protected safety latch, or reset-held safe state. |
| **DFC-SAFE-0005** | No host-visible field shall directly request an active logical safety-output level. |
| **DFC-SAFE-0006** | Each logical safety-output activation shall require an active authorized hardware response source and every enabling condition stated by DFC-FUNC-0112. |
| **DFC-SAFE-0007** | Reset, global inhibit, observational mode, TEST_DEBUG, production test, and channel disable shall take priority over response requests and configured active polarity. |
| **DFC-SAFE-0008** | An unsatisfied enabled interlock or active fault inhibit shall take priority over an otherwise authorized response request. |
| **DFC-SAFE-0009** | A new qualifying fault, interlock, watchdog, lost-link, or safety-output condition shall dominate a simultaneous host clear of the same evidence. |
| **DFC-SAFE-0010** | A recoverable fault shall not disable an unaffected function unless an explicitly authorized system-level safety response requires that action. |
| **DFC-SAFE-0011** | A nonrecoverable or designated critical fault shall cause FAULTED, preserve available diagnostic evidence, and apply only the fixed or configured authorized safe responses. |
| **DFC-SAFE-0012** | Active fault evidence shall clear only when the source is inactive and the Architecture-defined recovery condition is satisfied; sticky fault evidence shall clear only by authorized clear or applicable reset. |
| **DFC-SAFE-0013** | Dragon Core shall preserve simultaneous fault-source identity, deterministic primary-fault selection, and the distinction between active and historical fault evidence. |
| **DFC-SAFE-0014** | A watchdog timeout shall initiate only the event, interrupt, fault, interlock, and logical safety responses authorized for the watchdog source. |
| **DFC-SAFE-0015** | A lost-link condition shall initiate only the event, interrupt, fault, interlock, and logical safety responses authorized for that lost-link source. |
| **DFC-SAFE-0016** | An interlock violation shall prevent its guarded action before or in the same externally effective update in which the violation becomes qualified. |
| **DFC-SAFE-0017** | Dragon Core shall record enabled watchdog timeout, fault assertion and recovery, interlock violation and recovery, lost-link assertion and recovery, safety-output request, activation, inhibition, and deactivation events. |
| **DFC-SAFE-0018** | Safety events shall contain raw timestamps, preserve chronological order while retained, and remain host-retrievable without suspending safety supervision. |
| **DFC-SAFE-0019** | Rejected safety configuration shall leave the prior protected state unchanged, set diagnostic evidence, and be eligible for timestamped event recording. |
| **DFC-SAFE-0020** | Observational mode shall permit monitoring, receive-only communication behavior, evidence collection, status retrieval, and hardware safety supervision while inhibiting every externally effective logical safety-output action. |
| **DFC-SAFE-0021** | Loss, reset, stall, or corruption of host communication shall not clear active safety configuration, terminate autonomous safety supervision, or activate a logical safety output. |
| **DFC-SAFE-0022** | A buffer overflow, event-store overflow, or evidence-reporting failure shall not bypass a safety inhibit or prevent the underlying active safety condition from remaining host-visible through its primary status path. |
| **DFC-SAFE-0023** | External power-driver circuitry shall remain the sole owner of final aircraft-energy control; Dragon Core shall provide only low-voltage logical commands. |

## 10. Reliability and Fault-Tolerance Requirements

| Requirement ID | Requirement |
|---|---|
| **DFC-REL-0001** | Dragon Core shall reach a deterministic safe host-access-ready state after every valid power-up or functional reset without executing software. |
| **DFC-REL-0002** | Dragon Core shall continue all unaffected monitoring, reporting, event, databus, routing, and safety-supervision functions after a recoverable localized fault. |
| **DFC-REL-0003** | A fault confined to one external interface or optional function shall not disable an unaffected interface or function unless an authorized system-level safety response requires it. |
| **DFC-REL-0004** | Dragon Core shall continue enabled hardware monitoring and safety supervision while host communication is absent, idle, stalled, malformed, or faulted. |
| **DFC-REL-0005** | Dragon Core shall preserve active volatile configuration during normal powered operation and host unavailability. |
| **DFC-REL-0006** | After host communication is restored, the host shall be able to retrieve current status, sticky evidence, saturating counts, and every retained event record not previously cleared or overwritten. |
| **DFC-REL-0007** | A malformed or corrupted SPI transaction shall not alter protected configuration, safety state, routing state, retained event contents, or unrelated register state. |
| **DFC-REL-0008** | Every host-visible sticky fault, error, overflow, rejection, and pending indication shall remain readable until its specified authorized clear, source-clearing condition, overwrite, or reset. |
| **DFC-REL-0009** | Finite queue full, empty, overflow, underflow, timeout, and drop conditions shall have bounded deterministic behavior and persistent loss evidence. |
| **DFC-REL-0010** | Reserved interrupt, fault, event, route, response, message, command, status, and test encodings shall not create an operational action. |
| **DFC-REL-0011** | Reset of one eligible module shall not clear unrelated module configuration or evidence and shall not corrupt a transaction or queue owned by another function. |
| **DFC-REL-0012** | A reset affecting both sides of an externally visible transfer shall abort or flush the transfer deterministically and shall prevent partial data from becoming valid. |
| **DFC-REL-0013** | All externally visible counts identified as saturating shall remain at their maximum value until cleared and shall not wrap to zero. |
| **DFC-REL-0014** | All externally visible sequence values identified as wrapping shall wrap modulo their defined width without changing the associated retained data. |
| **DFC-REL-0015** | Loss of one event report shall not clear or conceal the primary sticky status and count that identify the underlying loss condition. |
| **DFC-REL-0016** | Technology-specific FPGA or ASIC wrappers shall preserve the same logical reset, interface, queue, timing, error, and register behavior required by this SRS. |

## 11. Environmental and Physical-Integration Requirements

These requirements define invariant logical behavior and operating assumptions. Technology-specific process, package, power, pad, timing, scan, thermal, and physical limits are owned by the future ASIC Integration Specification identified by `RCA-DFC-CHTR-002`, Section 3.3.

| Requirement ID | Requirement |
|---|---|
| **DFC-ENV-0001** | Dragon Core logical behavior shall remain conforming throughout the valid electrical, clock, reset, thermal, and timing operating limits supplied by the applicable qualified platform integration. |
| **DFC-ENV-0002** | The ECP5 FPGA validation realization shall preserve the complete logical behavior of this SRS in a laboratory ambient temperature range of 0 degrees Celsius through 50 degrees Celsius and within all other characterized limits of the selected FPGA, board, transceivers, power supplies, and installation. |
| **DFC-ENV-0003** | FPGA-specific and ASIC-specific clocks, resets, memories, I/O cells, test resources, and technology primitives shall remain behind controlled wrappers and shall not change externally required behavior. |
| **DFC-ENV-0004** | Board-level protection, voltage translation, termination, isolation, transceivers, analog conditioning, power conversion, connectors, and aircraft wiring shall remain outside the Dragon Core logical boundary. |
| **DFC-ENV-0005** | An unused, reserved, disabled, or uncommitted logical output or output-enable shall assume its specified deterministic safe state in reset, normal operation, and test operation. |
| **DFC-ENV-0006** | The future physical implementation shall preserve the 44-functional-pad and three-production-test-pad logical population and shall not repurpose a logical pad in a way that changes this SRS. |

## 12. Protected Access, Test, and Diagnostic Requirements

| Requirement ID | Requirement |
|---|---|
| **DFC-SEC-0001** | Protected-write authorization, production-test authorization, and engineering-only controls shall be inactive after reset. |
| **DFC-SEC-0002** | Engineering-only commands and interfaces shall be uniquely identified and shall not be reachable through undocumented production transactions. |
| **DFC-SEC-0003** | Dragon Core shall report active TEST_DEBUG, physical test authorization, qualified test-active state, command completion, command rejection, and safety-blocked evidence. |
| **DFC-SEC-0004** | TEST_DEBUG shall be entered only while qualified test operation is active, initialization is complete, and no higher-priority operating-state condition applies. |
| **DFC-SEC-0005** | Qualified test-active state and reported TEST_DEBUG test authorization shall derive from the same physical authorization condition and shall not disagree. |
| **DFC-SEC-0006** | Deauthorization or reset during a production-test command shall return TEST_DATA to high impedance, terminate the test operation deterministically, preserve required rejection or abort evidence, and leave every safety output inactive. |
| **DFC-SEC-0007** | CAPTURE shall atomically sample the Architecture-defined 256-bit diagnostic vector without modifying captured functional state. |
| **DFC-SEC-0008** | SHIFT shall transfer only the requested one through 256 captured bits through TEST_DATA using the Architecture-defined argument and bit order and shall not expose arbitrary memory or register contents. |
| **DFC-SEC-0009** | Each of the eight loopback selections shall be bounded to the Architecture-defined internal or fixture-safe endpoints and shall remain inactive unless separately selected and authorized. |
| **DFC-SEC-0010** | Fault injection shall be available only for the finite test sources defined by the Architecture, shall be distinguishable from naturally detected faults, and shall not suppress a natural fault. |
| **DFC-SEC-0011** | Every rejected privileged or test transaction shall set diagnostic status and shall be eligible for timestamped event recording without changing protected functional state. |
| **DFC-SEC-0012** | User logic, routing, production test, and platform wrappers shall provide no direct access to clocks, resets, unrestricted pad controls, privileged writes, host-transport control, or logical safety-output activation. |

## 13. Requirement Population

| Category | Identifier range | Requirements |
|---|---|---:|
| Functional behavior | `DFC-FUNC-0001` through `DFC-FUNC-0138` | 138 |
| External and host interfaces | `DFC-INTF-0001` through `DFC-INTF-0062` | 62 |
| Configuration and protection | `DFC-CONF-0001` through `DFC-CONF-0035` | 35 |
| Performance and timing | `DFC-PERF-0001` through `DFC-PERF-0026` | 26 |
| Safety behavior | `DFC-SAFE-0001` through `DFC-SAFE-0023` | 23 |
| Reliability and fault tolerance | `DFC-REL-0001` through `DFC-REL-0016` | 16 |
| Environmental and physical integration | `DFC-ENV-0001` through `DFC-ENV-0006` | 6 |
| Protected access, test, and diagnostics | `DFC-SEC-0001` through `DFC-SEC-0012` | 12 |
| **Total** | | **318** |

Requirement identifiers are contiguous within each category. Verification methods and cases are owned by the Verification Plan; relationships among these requirements, Architecture contracts, register fields, RTL modules, and verification cases are owned by the RTM.
