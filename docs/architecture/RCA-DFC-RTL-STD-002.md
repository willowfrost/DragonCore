# Dragon Core RTL Coding Standard

- **Document ID:** RCA-DFC-RTL-STD-002
- **Product:** Dragon Core Revision A
- **Purpose:** Define mandatory SystemVerilog implementation practices for Dragon Core functional RTL, generated RTL, technology wrappers, assertions, and synthesis-facing artifacts.

## 1. Purpose and Scope

This standard defines the coding practices required to implement Dragon Core as deterministic, synthesizable, processor-free hardware. It applies to:

- RTL-001 through RTL-024;
- reusable packages and helper modules;
- generated register and interface logic;
- FPGA and ASIC technology wrappers;
- synthesizable assertions and bounded verification hooks; and
- source, constraint, and generation artifacts required to build the design.

This standard defines **how RTL is written**. It does not redefine:

- product mission or exclusions owned by the Charter;
- product and interface ownership owned by the PBIO;
- externally observable behavior or quantitative requirements owned by the SRS;
- internal protocols, state encodings, ports, clocks, resets, CDC/RDC structures, capacities, or allocations owned by the Architecture;
- register offsets, fields, access semantics, reset values, legal values, or side effects owned by the Register Map;
- verification methods, environments, or completion criteria owned by the Verification Plan; or
- requirement relationships owned by the RTM.

A rule in this standard shall be interpreted using the current controlling technical definition in the owning document. This standard shall not be used as an alternate source for a copied value or encoding.

## 2. Specification Use and Ambiguity Resolution

Charter Section 3 is the sole definition of document subjects, single-owner rules, and derived-artifact authority. This standard consumes that definition and does not reproduce a second hierarchy.

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-GEN-001 | RTL shall implement only behavior defined by the controlling technical specifications and the applicable module specification. |
| RTLSTD-GEN-002 | A lower-level module specification or implementation shall not weaken, reinterpret, or create an alternate definition of a higher-level technical contract. |
| RTLSTD-GEN-003 | Values owned by another document shall be imported through generated definitions or referenced by identifier; they shall not be independently copied into source as a second authority. |
| RTLSTD-GEN-004 | Tool behavior or tool limitations shall not be treated as evidence that nonconforming RTL is technically correct. |
| RTLSTD-GEN-005 | Generated RTL shall satisfy the same external behavior, coding, synthesis, and verification obligations as hand-written RTL. |
| RTLSTD-GEN-006 | A conflict, ambiguity, omission, or incomplete technical definition shall be corrected in its owning specification before dependent RTL is implemented; the implementation shall not invent, infer, or select behavior locally. |
| RTLSTD-GEN-007 | Source comments, assertions, constraints, generation inputs, and module specifications shall cite owning identifiers whenever they consume a nonlocal technical fact. |
| RTLSTD-GEN-008 | A derived implementation choice may select only among alternatives expressly permitted by the owning specification and shall preserve every externally observable and cross-module contract. |

## 3. Normative Language and Rule Classes

The terms **shall** and **shall not** identify mandatory rules. **Should** identifies a preferred practice that may be departed from for a documented technical reason. **May** identifies a permitted option.

| Class | Meaning |
|---|---|
| Mandatory | Required for every applicable source or generated artifact. |
| Conditional | Required when the stated clock, reset, interface, safety, memory, or technology condition applies. |
| Preferred | Expected unless a documented technical reason supports another implementation. |
| Prohibited | Not permitted in synthesizable Dragon Core RTL. |

A technical deviation shall identify the affected rule, scope, technical reason, and verification impact. Administrative tracking is outside this document.

## 4. RTL Development Principles

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-PRIN-001 | Prefer explicit, finite, reviewable logic over compact constructs that hide state, priority, width, or side effects. |
| RTLSTD-PRIN-002 | Each module shall support independent compilation, lint, simulation, synthesis, and verification through declared ports and bounded external harnesses. |
| RTLSTD-PRIN-003 | Functional RTL shall remain technology independent. FPGA- and ASIC-specific resources shall remain behind the Architecture-defined wrappers. |
| RTLSTD-PRIN-004 | No silent loss is permitted. Rejection, overflow, underflow, timeout, CRC failure, access failure, routing failure, or dropped evidence shall produce the indication defined by the owning specification. |
| RTLSTD-PRIN-005 | Reset, startup, disabled, observational, test, fault, illegal, and unused states shall have deterministic behavior. |
| RTLSTD-PRIN-006 | Simultaneous-condition priority shall be explicit. Set-dominates-clear behavior shall be implemented wherever required by the Architecture or Register Map. |
| RTLSTD-PRIN-007 | The RTL shall contain no instruction-executing processor, firmware runtime, software memory, operating system, BSP, processor exception subsystem, or processor debug subsystem. |
| RTLSTD-PRIN-008 | Resource counts, queue depths, route counts, source allocations, interface populations, and user resources shall be obtained from the Architecture or Register Map rather than duplicated here. |
| RTLSTD-PRIN-009 | Required startup and safety behavior shall not depend on host software execution. |
| RTLSTD-PRIN-010 | Historical RTL, examples, platform templates, and testbench behavior shall not establish product functionality. |
| RTLSTD-PRIN-011 | Strict module isolation shall be preserved: RTL-001 through RTL-023 shall not instantiate, hierarchically reference, or directly access another functional child module. |
| RTLSTD-PRIN-012 | RTL-024 shall own integration-only structure and shall not absorb functional algorithms assigned to RTL-001 through RTL-023. |

## 5. SystemVerilog Language Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-LANG-001 | Synthesizable source shall use IEEE 1800 SystemVerilog constructs accepted by the selected parser, simulator, formal, synthesis, FPGA, and ASIC flows. |
| RTLSTD-LANG-002 | Use `logic`, `always_comb`, `always_ff`, packed structs, explicit enums, packages, parameters, local parameters, and generate constructs where supported by all required tools. |
| RTLSTD-LANG-003 | Classes, dynamic arrays, queues, mailboxes, program blocks, procedural randomization, delays, `force`/`release`, procedural continuous assignment, and file I/O are prohibited in synthesizable RTL. |
| RTLSTD-LANG-004 | Required hardware initialization shall not depend on `initial` blocks. FPGA-only memory initialization shall be isolated in a wrapper and behaviorally matched in the ASIC implementation. |
| RTLSTD-LANG-005 | Arithmetic, comparisons, masks, concatenations, shifts, and assignments shall use explicitly sized literals. |
| RTLSTD-LANG-006 | Signedness conversion, enum conversion, truncation, extension, and reinterpretation shall use explicit casts. |
| RTLSTD-LANG-007 | Synthesizable state and interfaces shall use four-state types. Two-state types may be used only in verification code where intentional. |
| RTLSTD-LANG-008 | Wildcard package imports shall not be used in functional RTL. Package qualification or explicit imports shall identify the source of every shared definition. |
| RTLSTD-LANG-009 | Directives affecting semantics, assertion enablement, timescale, default net type, or synthesis defines shall be centralized. |
| RTLSTD-LANG-010 | Implicit nets shall be disabled by ``default_nettype none`` or equivalent tool enforcement. |
| RTLSTD-LANG-011 | Source shall not depend on simulator-specific scheduling, implementation-defined expression sizing, or unspecified X behavior. |
| RTLSTD-LANG-012 | Synthesis pragmas shall be narrowly scoped, tool documented, and behaviorally neutral unless contained in an Architecture-defined technology wrapper. |

## 6. Repository and Generated-Artifact Organization

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-ORG-001 | Each source file shall contain one primary synthesizable module, and the filename shall match the module name. |
| RTLSTD-ORG-002 | Packages, functional RTL, wrappers, assertions, formal harnesses, simulation code, generated files, scripts, and constraints shall reside in separate directories. |
| RTLSTD-ORG-003 | Generated SystemVerilog, software headers, verification data, and documentation shall be produced from controlled machine-readable sources and shall not be edited manually. |
| RTLSTD-ORG-004 | Generation shall fail on duplicate identifiers, duplicate offsets, overlapping fields, unknown access classes, missing reserved coverage, unresolved widths, or inconsistent allocations. |
| RTLSTD-ORG-005 | Generated outputs shall record the source hash and generator hash in a machine-readable manifest or file header. |
| RTLSTD-ORG-006 | Simulation-only and formal-only source shall not appear in production synthesis file lists. |
| RTLSTD-ORG-007 | FPGA and ASIC builds shall share the same technology-independent RTL-001 through RTL-024 source and shall differ only in Architecture-defined wrappers and implementation files. |
| RTLSTD-ORG-008 | Obsolete or exploratory implementation files shall not remain as alternate active compile paths. |
| RTLSTD-ORG-009 | Compile order shall be explicit and deterministic. Package dependencies shall be acyclic. |
| RTLSTD-ORG-010 | A clean build from source and generation inputs shall reproduce all build inputs without manual editing. |

Recommended directory classes are:

```text
rtl/infrastructure
rtl/monitoring
rtl/safety
rtl/databus
rtl/user
rtl/top
rtl/wrappers
rtl/packages
verification/assertions
verification/formal
verification/simulation
generated
constraints
scripts
```

## 7. Source-File and Module Structure

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-MOD-001 | Each module header shall identify the module name, purpose, controlling module specification, clocks, resets, formal interfaces, and register ownership. |
| RTLSTD-MOD-002 | Ports shall be grouped consistently: clocks, resets, control interfaces, configuration, status, functional inputs, functional outputs, evidence interfaces, and bounded test hooks. |
| RTLSTD-MOD-003 | Every port shall have explicit direction, type, and packed width. |
| RTLSTD-MOD-004 | Port names, directions, widths, types, producers, consumers, and CDC/RDC treatment shall match the Architecture formal port catalog. |
| RTLSTD-MOD-005 | Module parameters shall exist only where the Architecture or wrapper strategy requires configurability. Parameters shall not alter the host-visible contract or fixed interface population. |
| RTLSTD-MOD-006 | Combinational decode, sequential state, and interface handshakes shall be separated where doing so improves ownership and verification. |
| RTLSTD-MOD-007 | Every state-holding object shall have exactly one procedural owner. |
| RTLSTD-MOD-008 | Technology primitives, pad cells, memory macros, clock cells, scan cells, and vendor primitives shall not appear in technology-independent functional modules. |
| RTLSTD-MOD-009 | Unused ports shall be deterministically tied or intentionally consumed. Accidental undriven, multiply driven, or floating signals are prohibited. |
| RTLSTD-MOD-010 | Module-local helper logic shall not create an undocumented external interface or alternate ownership path. |
| RTLSTD-MOD-011 | RTL-024 shall be the sole functional integration top and shall instantiate exactly one instance of each RTL-001 through RTL-023 module required by the Architecture. |
| RTLSTD-MOD-012 | RTL-024 external ports shall be limited to the wrapper/platform-facing logical ports in the Architecture port catalog; child-to-child connections shall not be exposed as RTL-024 ports. |
| RTLSTD-MOD-013 | All DRI, control/status, interrupt, event, fault, safety-response, canonical-message, shared-buffer, clock/reset-distribution, and production-test child connections shall be explicit RTL-024 internal nets with one producer and the Architecture-defined consumers. |
| RTLSTD-MOD-014 | RTL-024 shall not use hierarchical references into child state. Integration shall use only declared child ports and shared package types. |
| RTLSTD-MOD-015 | Standalone child compilation shall use bounded stubs or harnesses outside production RTL; production child source shall not contain integration-only conditional ports or alternate topologies. |

## 8. Naming and Type Conventions

| Object | Convention | Example |
|---|---|---|
| Module | `dfc_` prefix, lower snake case | `dfc_timestamp_engine` |
| Package | `dfc_` prefix and `_pkg` suffix | `dfc_types_pkg` |
| Parameter/local parameter | upper snake case | `FIFO_DEPTH` |
| Signal | lower snake case | `event_pending` |
| Active-low signal | `_n` suffix | `core_rst_n` |
| Clock | `_clk` suffix or Architecture name | `core_clk` |
| Registered state | `_q` suffix | `state_q` |
| Next/combinational state | `_d` suffix | `state_d` |
| Input/output port | `_i` / `_o` suffix | `evt_valid_o` |
| Output enable | `_oe_o` suffix | `gpio_oe_o` |
| One-cycle action | `_pulse`, `_req`, or command-specific verb | `snapshot_req` |
| Enum type | `_e` suffix | `dri_state_e` |
| Packed structure type | `_t` suffix | `dfc_event_record_t` |

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-NAME-001 | Generated register and field identifiers shall match the Register Map exactly. |
| RTLSTD-NAME-002 | Acronyms shall have one consistent spelling across names and one consistent uppercase spelling in constants. |
| RTLSTD-NAME-003 | Ambiguous names such as `temp`, `data1`, `flag`, `misc`, `spare`, or `future` are prohibited outside a small, obvious local scope. |
| RTLSTD-NAME-004 | Width, signedness, units, scaling, and semantic meaning shall be evident from the type or adjacent declaration. |
| RTLSTD-NAME-005 | Reserved identifiers shall not be reused for unrelated functions. |
| RTLSTD-NAME-006 | Shared enums and packed structures shall be declared once in the Architecture-controlled shared packages. |
| RTLSTD-NAME-007 | A local alias shall not obscure the identity of a shared protocol, register, event, interrupt, fault, or route identifier. |

## 9. Clock Coding Rules

The Architecture is the sole authority for clock-domain membership, clock frequencies, clock ownership, and allowed crossings.

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-CLK-001 | Functional modules shall use the Architecture-assigned clock and synchronous clock enables. |
| RTLSTD-CLK-002 | RTL-generated clocks and combinational clock gating are prohibited. |
| RTLSTD-CLK-003 | Integrated clock-gating cells may appear only in a technology wrapper with appropriate timing, test, and equivalence constraints. |
| RTLSTD-CLK-004 | SPI clocked state shall be limited to the Architecture-defined SPI shift, framing, CRC, and mailbox-side logic. |
| RTLSTD-CLK-005 | Production-test clocks shall remain isolated from normal functional state. |
| RTLSTD-CLK-006 | Clock enables shall be synchronous to the receiving clock and free of combinational glitches. |
| RTLSTD-CLK-007 | A data signal shall not be used as a clock. Edge detection shall use synchronized data in the receiving domain. |
| RTLSTD-CLK-008 | Every source file shall identify each clock domain used within the module. |
| RTLSTD-CLK-009 | Clock muxing shall use an Architecture-defined technology cell or wrapper structure and shall not be inferred from ordinary combinational logic. |
| RTLSTD-CLK-010 | Clock-domain assumptions used by assertions or constraints shall match the Architecture CDC/RDC inventory. |

## 10. Reset and Reset-Domain Rules

The Architecture is the sole authority for reset sources, polarity, assertion, release, scope, and special reset sequences.

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-RST-001 | Reset assertion and release shall implement the exact Architecture reset contract for the receiving domain. |
| RTLSTD-RST-002 | No logic shall generalize reset release to “synchronized per domain” when the Architecture defines a specific exception or qualification sequence. |
| RTLSTD-RST-003 | Functional logic shall not use an unqualified reset release as data, enable, or a transaction indication. |
| RTLSTD-RST-004 | Local module reset requests shall be synchronized and scope qualified in the receiving functional domain. |
| RTLSTD-RST-005 | Every state-holding object shall reset to the value defined by the Register Map, Architecture, or module specification. |
| RTLSTD-RST-006 | Reset shall return valid/ready interfaces, DRI state, commands, FIFOs, mailboxes, snapshots, staging state, authorization state, and ownership toggles to their defined idle state. |
| RTLSTD-RST-007 | Reset affecting one side of an interface shall reset both sides or execute the Architecture-defined flush and recovery sequence. |
| RTLSTD-RST-008 | Reset shall not create a false transaction, response, interrupt, event, fault, route, transmission, threshold crossing, watchdog service, or output activation. |
| RTLSTD-RST-009 | Reset values owned by the Register Map shall be imported from generated definitions. Hand-copied duplicate reset constants are prohibited. |
| RTLSTD-RST-010 | Reset-domain crossings shall be inventoried, constrained, and verified separately from ordinary clock-domain crossings. |
| RTLSTD-RST-011 | Outputs and enables with a defined safe state shall assume that state throughout reset and reset recovery. |
| RTLSTD-RST-012 | Reset release shall be covered by assertions for idle state, recovery ordering, absence of false activity, and first legal transaction behavior. |

## 11. CDC and Asynchronous-Input Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-CDC-001 | Every clock or asynchronous boundary shall match an entry in the Architecture CDC/RDC inventory. |
| RTLSTD-CDC-002 | A stable single-bit level may use the Architecture-defined synchronizer structure. Functional logic shall not consume the first synchronizer stage. |
| RTLSTD-CDC-003 | A pulse shall cross domains only through a handshake, toggle, counter, or pulse-stretch structure that guarantees capture for all permitted clock ratios. |
| RTLSTD-CDC-004 | An independently changing multi-bit bus shall not be qualified by a separately synchronized control signal. |
| RTLSTD-CDC-005 | Multi-bit command and response transfers shall use the Architecture-defined mailbox or handshake structure. |
| RTLSTD-CDC-006 | Mailbox source data shall remain stable until ownership or acknowledgement returns. |
| RTLSTD-CDC-007 | Combinational paths across clock domains are prohibited. |
| RTLSTD-CDC-008 | Asynchronous external inputs shall be synchronized and qualified before use by counters, state machines, event logic, interrupt logic, routing, or safety logic. |
| RTLSTD-CDC-009 | Synchronizer attributes and preservation constraints shall be applied through centralized wrappers or constraints. |
| RTLSTD-CDC-010 | CDC assertions shall check payload stability, ordering, no overwrite, no duplicate acceptance, bounded acknowledgement, and reset recovery. |
| RTLSTD-CDC-011 | Direct use of asynchronous inputs in arithmetic, state transitions, counters, or safety decisions is prohibited except for reset assertion explicitly permitted by the Architecture. |
| RTLSTD-CDC-012 | A CDC structure shall not be modified merely to silence a structural tool without preserving the Architecture-defined transfer semantics. |
| RTLSTD-CDC-013 | Production-test crossings and reset interactions shall implement `CDC-TEST-001`, `CDC-TEST-002`, `CDC-TEST-003`, and `RDC-TEST-001` exactly, including source stability, ownership, qualification, deauthorization, reconvergence, and constraint treatment. |
| RTLSTD-CDC-014 | Independently synchronized replicas of one asynchronous source shall not reconverge in functional logic unless the Architecture explicitly defines and constrains the reconvergence. |

## 12. SPI Host-Access Implementation Rules

The SRS owns externally observable SPI behavior and timing requirements. The Architecture owns SPI framing, parser, CRC, wait-fill, mailbox, DRI execution, abort, and response structure. This standard defines only coding practices.

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-SPI-001 | The bridge shall implement the SPI mode, bit order, framing, command, response, and CRC behavior defined by the SRS and Architecture. |
| RTLSTD-SPI-002 | Command collection, command CRC, response construction, response CRC, wait-fill generation, and SCLK-domain ownership shall be separate state objects with explicit reset and frame-start initialization. |
| RTLSTD-SPI-003 | A command-accepted pulse shall occur exactly once, only when the final command-CRC bit is sampled while chip select remains asserted and opcode, count, reserved count bits, length, alignment, and CRC checks all pass. |
| RTLSTD-SPI-004 | No DRI request, protected-write consumption, target-register modification, command completed-count increment, or functional command pulse shall occur before the command-accepted pulse. |
| RTLSTD-SPI-005 | Chip-select deassertion before acceptance shall discard the partial frame, clear transaction-scoped protected authorization, set the defined sticky pre-acceptance-abort evidence and saturating abort counter, and shall not modify the last accepted-transaction result. |
| RTLSTD-SPI-006 | A pre-acceptance abort shall not attempt to shift an abort response in the terminated frame; its evidence shall be observable only through a later valid transaction. |
| RTLSTD-SPI-007 | An accepted command shall cross to CORE_CLK through the Architecture-defined one-outstanding stable-payload ownership mailbox. Direct sampling of a multi-bit SCLK-domain command in CORE_CLK is prohibited. |
| RTLSTD-SPI-008 | Multiword execution shall be ordered and non-atomic. The completed-word count shall increment only on an OK DRI response; execution shall stop at the first failing word; earlier successful writes shall remain committed and later words shall not execute. |
| RTLSTD-SPI-009 | Transport logic shall not create atomic multiword behavior. Atomic activation shall use only Register Map staging, validation, and commit objects. |
| RTLSTD-SPI-010 | Chip-select deassertion after command acceptance may terminate response shifting, but shall not cancel CORE_CLK execution, roll back a completed write, restore consumed authorization, or replace the terminal result. It shall set the defined response-truncation evidence and abort counter. |
| RTLSTD-SPI-011 | Response marker, status, completed count, reserved byte, read data, and CRC shall be constructed as one stable object before response-mailbox ownership transfers to SCLK. Response CRC shall exclude wait-fill and CRC bytes exactly as defined by the SRS. |
| RTLSTD-SPI-012 | Wait-fill insertion, response length, read-data inclusion, and MISO output enable shall be driven from explicit response phase state. MISO shall be high impedance whenever chip select is inactive. |
| RTLSTD-SPI-013 | SPI shift, framing, and CRC logic shall not directly decode register addresses or access functional module state; all accepted word operations shall use DRI. |
| RTLSTD-SPI-014 | The reset-release quiet interval and chip-select-to-first-clock setup interval shall be implemented by explicit qualified state. A timing constraint or testbench delay alone shall not make an otherwise unqualified frame legal. |
| RTLSTD-SPI-015 | Before quiet-interval qualification, the parser shall remain idle, reject frame acceptance, hold MISO disabled, and produce no mailbox or DRI activity. |
| RTLSTD-SPI-016 | CRC parameters, opcodes, status values, marker, count limits, frame field locations, and timing limits shall come from their generated owning definitions; locally copied protocol literals are prohibited. |
| RTLSTD-SPI-017 | Command and response mailbox state shall prevent overwrite, duplicate ownership transfer, duplicate execution, and reuse of stale response data across reset or aborted frames. |
| RTLSTD-SPI-018 | Assertions shall cover exact acceptance, all pre-acceptance rejection paths, pre- and post-acceptance aborts, authorization clearing, mailbox stability, one execution per accepted command, completed-count updates, stop-on-first-error, response stability, CRC coverage, quiet-interval gating, and MISO disable. |

## 13. DRI and Internal Interface Rules

The Architecture owns the DRI signal set, widths, completion codes, ordering, latency, timeout, and reset behavior.

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-DRI-001 | DRI source and endpoint logic shall implement the exact Architecture request/response protocol. |
| RTLSTD-DRI-002 | Request fields shall remain stable while a valid request is waiting for acceptance. |
| RTLSTD-DRI-003 | The implementation shall not accept more outstanding operations than the Architecture permits. |
| RTLSTD-DRI-004 | Exactly one response shall correspond to each accepted request unless reset or an Architecture-defined abort invalidates the transaction. |
| RTLSTD-DRI-005 | Response fields shall remain stable while a valid response is waiting for acceptance. |
| RTLSTD-DRI-006 | Timeout logic shall use the Architecture-defined boundary and shall suppress late side effects or late responses. |
| RTLSTD-DRI-007 | Decode, alignment, strobe, access, protection, endpoint, and timeout errors shall not modify target or unrelated state. |
| RTLSTD-DRI-008 | DRI address and completion-code constants shall come from Architecture-controlled packages. |
| RTLSTD-DRI-009 | Assertions shall check request stability, outstanding-operation limits, response uniqueness, response stability, timeout, reset-to-idle, and error side-effect exclusion. |
| RTLSTD-DRI-010 | Other valid/ready interfaces shall follow the same stability and transfer-edge discipline unless their Architecture contract explicitly defines another protocol. |
| RTLSTD-DRI-011 | DRI acceptance shall be the single CORE_CLK edge on which request VALID and READY are both asserted; decode, first-error selection, timeout age, and side-effect eligibility shall derive from that accepted request object. |
| RTLSTD-DRI-012 | RTL-001 shall commit a successful write side effect only in the same cycle that it commits the corresponding OK response; a non-OK response shall have no target or unrelated side effect. |
| RTLSTD-DRI-013 | An endpoint operation shall use an explicit pending token or equivalent tracked ownership state so that reset, cancellation, or timeout invalidates side-effect eligibility before a late endpoint indication can modify state. |
| RTLSTD-DRI-014 | A timed-out request shall produce one terminal timeout result and shall never be followed by a second response or a late untracked write. Endpoint logic shall either complete before timeout or observe cancellation before any commit. |
| RTLSTD-DRI-015 | First-error selection shall preserve the Architecture-defined validation order and shall not be changed by parallel decode, synthesis optimization, or endpoint response timing. |

## 14. Register-Contract Implementation Rules

The Register Map is the sole authority for register addresses, fields, access classes, reset values, legal values, protection, commands, and side effects.

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-REG-001 | RTL-001 shall remain the sole host-visible DRI register endpoint. Other modules shall receive decoded controls and return typed status through Architecture-defined interfaces. |
| RTLSTD-REG-002 | Register decode, field extraction, access enforcement, reset values, and masks shall use generated definitions from the Register Map source. |
| RTLSTD-REG-003 | Reads, writes, commands, clears, sets, protection, snapshots, proxies, pops, validation, and commits shall implement the exact Register Map semantics. |
| RTLSTD-REG-004 | Read-to-clear behavior is prohibited unless the Register Map explicitly introduces such an access class. |
| RTLSTD-REG-005 | Reserved and unimplemented behavior shall match the Register Map and shall create no unrelated side effect. |
| RTLSTD-REG-006 | Illegal values or illegal access types shall reject the complete affected operation as specified. |
| RTLSTD-REG-007 | Authorization state shall implement the exact key sequence, scope, consumption, expiry, and invalidation rules owned by the Register Map. |
| RTLSTD-REG-008 | Sticky evidence logic shall implement the specified simultaneous set/clear priority. |
| RTLSTD-REG-009 | A command write shall produce one bounded action and shall not create repeated action while a request or response is stalled. |
| RTLSTD-REG-010 | Staging registers shall not alter active behavior until validation and commit succeed. |
| RTLSTD-REG-011 | Reset shall invalidate incomplete staging, snapshots, pending commands, and authorization where required. |
| RTLSTD-REG-012 | Status used in an accepted read response shall remain stable until response acceptance. |
| RTLSTD-REG-013 | Manual duplication of offsets, masks, access classes, reset values, field widths, legal encodings, or source allocations is prohibited. |
| RTLSTD-REG-014 | Generated register logic shall fail generation when the source contract is structurally incomplete or inconsistent. |
| RTLSTD-REG-015 | Register assertions shall cover access legality, reset values, reserved bits, no-side-effect rejection, protection, commands, W1C/W1S priority, staging, and response stability. |
| RTLSTD-REG-016 | A whole-value saturating counter clear shall decode an accepted write of all ones into one one-cycle clear pulse, treat an accepted write of zero as no effect, and reject every other value with an access error. A 32-bit bitwise clear mask shall not be generated for that access class. |
| RTLSTD-REG-017 | True source-mask evidence fields shall implement bitwise W1C independently of the whole-counter-clear rule. New hardware assertion shall dominate a simultaneous host clear wherever the Register Map specifies set-dominates-clear. |

## 15. Combinational Logic Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-COMB-001 | Use `always_comb` for combinational procedural logic. |
| RTLSTD-COMB-002 | Assign every output and temporary a deterministic default before conditional logic. |
| RTLSTD-COMB-003 | Use blocking assignments in combinational processes. Nonblocking assignments are prohibited in purely combinational logic. |
| RTLSTD-COMB-004 | Every `case` statement shall define safe behavior for unmatched values. |
| RTLSTD-COMB-005 | `unique` and `priority` qualifiers shall be used only when their semantics are intentional and asserted. |
| RTLSTD-COMB-006 | `casex` is prohibited. `casez` may be used only for a documented wildcard encoding with explicit reserved and X behavior. |
| RTLSTD-COMB-007 | X values shall not be used as synthesis don’t-cares for functional, safety, register, or externally visible behavior. |
| RTLSTD-COMB-008 | Combinational feedback and inferred storage are prohibited. |
| RTLSTD-COMB-009 | Arithmetic, comparisons, shifts, masks, concatenations, and reductions shall use explicit widths and signedness. |
| RTLSTD-COMB-010 | Arbitration and priority logic shall define deterministic no-request, one-request, and simultaneous-request behavior. |
| RTLSTD-COMB-011 | Large decoders shall be generated or partitioned so complete review and coverage remain practical. |
| RTLSTD-COMB-012 | Combinational outputs crossing a module boundary shall not glitch where the receiving contract requires registered or stable behavior. |

## 16. Sequential Logic Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-SEQ-001 | Use `always_ff` for clocked state. |
| RTLSTD-SEQ-002 | Use nonblocking assignments for sequential state updates. |
| RTLSTD-SEQ-003 | A state object shall not be assigned by more than one sequential process. |
| RTLSTD-SEQ-004 | Every state-holding object shall have a defined reset value or explicitly defined retention behavior. |
| RTLSTD-SEQ-005 | Clock enables shall be synchronous conditions within `always_ff`; functional RTL shall not gate clocks directly. |
| RTLSTD-SEQ-006 | State transitions, counters, sticky evidence, and command pulses shall define simultaneous-condition priority explicitly. |
| RTLSTD-SEQ-007 | Set-dominates-clear behavior shall be visible in the code structure rather than dependent on obscure statement ordering. |
| RTLSTD-SEQ-008 | Splitting unrelated state into separate processes shall not create multiple writers or inconsistent priority. |
| RTLSTD-SEQ-009 | Sequential behavior shall not depend on races between independently scheduled processes. |
| RTLSTD-SEQ-010 | Pipelining and retiming shall preserve specified ordering, latency, reset, and handshake behavior. |
| RTLSTD-SEQ-011 | One-cycle pulses shall be asserted for exactly one receiving-clock edge per accepted action. |
| RTLSTD-SEQ-012 | Counters and state shall not update on an interface request until the protocol-defined acceptance edge occurs. |

## 17. FSM and Control-Logic Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-FSM-001 | FSM state types shall use `typedef enum logic` with explicit width and named legal states. |
| RTLSTD-FSM-002 | Every FSM shall have a defined reset state and startup path. |
| RTLSTD-FSM-003 | A state-register/next-state organization is preferred. Another form shall retain equally explicit state, priority, and output behavior. |
| RTLSTD-FSM-004 | Every state shall define outputs and transitions for all relevant inputs. |
| RTLSTD-FSM-005 | Illegal or corrupted states shall recover to the module-defined safe state and create required evidence. |
| RTLSTD-FSM-006 | One-hot encoding may be used only when justified and when illegal combinations are detected or proven unreachable. |
| RTLSTD-FSM-007 | Safety, protection, reset, DRI, SPI, staging/commit, and routing FSMs shall include legal-transition and forbidden-state assertions. |
| RTLSTD-FSM-008 | Busy, ready, valid, complete, reject, and error outputs shall be registered or proven glitch free. |
| RTLSTD-FSM-009 | Timeouts and retry limits shall be finite, explicitly sized, and sourced from the owning specification. |
| RTLSTD-FSM-010 | An FSM shall not contain an unbounded loop, wait, retry, or host-dependent startup sequence. |
| RTLSTD-FSM-011 | State encoding shall use the Architecture-controlled shared enum where the state crosses module boundaries. |
| RTLSTD-FSM-012 | A local FSM enum shall not duplicate or redefine a system-wide operating-state encoding. |

## 18. Parameters, Constants, Packages, and Generated Definitions

The following package-to-owner mapping is mandatory. The package is a generated derivative of the cited normative owner and shall not acquire independent technical content.

| Generated package | Normative owner | Permitted content boundary |
|---|---|---|
| `dfc_constants_pkg.sv` | Architecture, `ARCH-TECH-004` and `ARCH-TECH-005` | Architecture-owned capacities, widths, endpoint identifiers, buffer-client and segment constants, protocol-internal constants, fixed allocations, and derived limits |
| `dfc_types_pkg.sv` | Architecture, Appendix B and `ARCH-TECH-005` | Shared packed records, module control/status types, safety-request types, enums, and interface payload types |
| `dfc_registers_pkg.sv` | Register Map, as bound by `ARCH-TECH-005` | Register addresses, fields, access classes, reset values, legal-value metadata, masks, and generated decode constants |
| `dfc_interrupt_pkg.sv` | Architecture, Appendices C and F and `ARCH-TECH-005` | Interrupt-source identifiers, subcondition allocation, masks, and interrupt-specific shared types or constants |
| `dfc_events_pkg.sv` | Architecture, Appendices C and F and `ARCH-TECH-005` | Event source identifiers, event identifiers, flags, subtype/data encodings, overflow identifiers, and event-specific shared types or constants |
| `dfc_version_pkg.sv` | Architecture, `ARCH-TECH-005` | Controlled build-supplied implementation parameters only; no document-tracking, date-derived state, or runtime configuration |

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-PKG-001 | Register definitions, shared types, protocol constants, interrupt/fault/event identifiers, route endpoints, capacities, and encodings shall be defined once in the owning generated package. |
| RTLSTD-PKG-002 | Packages shall not contain hidden elaboration side effects or tool-specific initialization behavior. |
| RTLSTD-PKG-003 | Parameters shall use explicit types and legal-value checks where supported. |
| RTLSTD-PKG-004 | Parameters shall not alter fixed external interfaces, register maps, source allocations, product boundaries, or safety behavior. |
| RTLSTD-PKG-005 | Use `localparam` for internal derived constants not intended as module configuration. |
| RTLSTD-PKG-006 | Magic numbers are prohibited except obvious explicitly sized zero/one and all-zero/all-one values. |
| RTLSTD-PKG-007 | Packed structs and enums crossing module boundaries shall have one stable bit-level definition in a shared package. |
| RTLSTD-PKG-008 | Package dependency order shall be acyclic and explicit. |
| RTLSTD-PKG-009 | Deprecated identifiers shall not be silently reused. |
| RTLSTD-PKG-010 | Generated packages, register models, and software headers shall be checked automatically for structural consistency. |
| RTLSTD-PKG-011 | A generated definition shall identify its owning source and source hash. |
| RTLSTD-PKG-012 | Source comments may explain a generated constant but shall not introduce a second normative value. |
| RTLSTD-PKG-013 | All six required generated packages shall be present in every production compile set that consumes their content, and exactly one definition of each package shall be active. |
| RTLSTD-PKG-014 | Functional RTL shall not redeclare a generated package constant, type, enum member, address, mask, source identifier, endpoint identifier, segment boundary, protocol status, event identifier, or version parameter under a local name. |
| RTLSTD-PKG-015 | Derived widths shall use `$bits`, typed array bounds, or generated width constants tied to the shared type; hand-maintained numeric copies of packed widths are prohibited. |
| RTLSTD-PKG-016 | Generation shall cross-check package contents against Architecture packed widths and allocations, Register Map field layouts, module port types, and the Verification Plan generated-consistency cases. |
| RTLSTD-PKG-017 | A package generator shall fail rather than emit a default, placeholder, reserved substitute, or guessed value when an owning definition is absent or inconsistent. |
| RTLSTD-PKG-018 | `dfc_version_pkg.sv` shall be parameterized from controlled build inputs and shall not encode a dated document state or imply automatic document-version tracking. |

## 19. Arithmetic, Counters, Timers, and Measurement Logic

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-ARITH-001 | Arithmetic operands and results shall use explicit widths, signedness, units, scaling, and overflow behavior. |
| RTLSTD-ARITH-002 | Counter width shall be derived from the owning maximum value and shall define behavior at zero, maximum, timeout, overflow, and reset. |
| RTLSTD-ARITH-003 | Saturating counters shall saturate and shall not wrap. |
| RTLSTD-ARITH-004 | Wrapping counters shall be used only when wrap behavior is explicitly required. |
| RTLSTD-ARITH-005 | Division, modulus, variable shift, and multiplication shall be reviewed for synthesizability, latency, resource use, corner cases, and FPGA/ASIC correspondence. |
| RTLSTD-ARITH-006 | Measurement logic shall define behavior for no edge, missing edge, minimum input rate, maximum input rate, timeout, overflow, and quantization. |
| RTLSTD-ARITH-007 | Fixed-point types shall identify the binary point, rounding, truncation, saturation, and legal range. |
| RTLSTD-ARITH-008 | Real-number and floating-point behavior are prohibited in synthesizable RTL unless a separate hardware architecture explicitly requires them. |
| RTLSTD-ARITH-009 | Raw timestamp state shall remain monotonic as defined by the Architecture; host correlation shall not rewrite the raw counter. |
| RTLSTD-ARITH-010 | Synthesizable loop bounds shall be statically finite and reviewable. |
| RTLSTD-ARITH-011 | Intermediate expression width shall be large enough to preserve the required result before intentional truncation or saturation. |
| RTLSTD-ARITH-012 | Divide-by-zero and illegal configuration values shall be structurally excluded or handled exactly as the owning specification requires. |
| RTLSTD-ARITH-013 | Raw timestamp counting and divider state shall run continuously after reset release while CORE_CLK is valid. Host control shall not gate the raw counter; correlation enable shall control only the Architecture-defined correlation function. |
| RTLSTD-ARITH-014 | Sensor values, thresholds, and hysteresis operands shall use signed 32-bit two's-complement types and explicitly signed comparisons. Host-versus-routed update arbitration and source/sequence retention shall implement the Architecture-defined priority without unsigned reinterpretation. |

## 20. Valid/Ready and Message-Interface Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-IF-001 | A source shall hold `valid` and the complete payload stable until an acceptance edge occurs. |
| RTLSTD-IF-002 | A source shall not withdraw or modify an offered item while `valid` is asserted and `ready` is low. |
| RTLSTD-IF-003 | A sink shall consume an item exactly once when `valid` and `ready` are both asserted on the active clock edge. |
| RTLSTD-IF-004 | Backpressure shall not corrupt, reorder, duplicate, or silently discard data. |
| RTLSTD-IF-005 | Interface record types and bit layouts shall use Architecture-controlled shared definitions. |
| RTLSTD-IF-006 | A module shall not infer permission to consume or transmit from a non-handshake status signal when a valid/ready contract exists. |
| RTLSTD-IF-007 | Arbitration among simultaneous sources shall use the Architecture-defined deterministic priority. |
| RTLSTD-IF-008 | Replication to multiple destinations shall implement the Architecture-defined independent acceptance and backpressure behavior. |
| RTLSTD-IF-009 | Reserved fields in shared records shall be driven to their defined value. |
| RTLSTD-IF-010 | Assertions shall cover stability, exact-once transfer, ordering, backpressure, reset, and overflow behavior. |

## 21. Interrupt, Event, Fault, and Evidence Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-EVID-001 | Source identifiers, event identifiers, interrupt positions, fault positions, flags, and record layouts shall use Architecture- and Register Map-controlled definitions. |
| RTLSTD-EVID-002 | Sticky evidence shall persist until the exact clear or reset condition defined by the owning specification. |
| RTLSTD-EVID-003 | New evidence shall dominate a simultaneous clear where required. |
| RTLSTD-EVID-004 | Interrupt acknowledgement shall remain distinct from clearing the underlying evidence. |
| RTLSTD-EVID-005 | Event producers shall follow the Architecture-defined handshake, payload, overflow, and drop-evidence contract. |
| RTLSTD-EVID-006 | Event timestamps and payloads shall be captured atomically at the defined event occurrence. |
| RTLSTD-EVID-007 | Event ordering, arbitration, storage, overwrite, and pop behavior shall implement the Architecture and Register Map without alternate local policy. |
| RTLSTD-EVID-008 | A producer shall not silently lose an event, fault, interrupt request, or safety evidence. |
| RTLSTD-EVID-009 | Fault classification, primary-source selection, response coordination, and recovery shall be deterministic. |
| RTLSTD-EVID-010 | Evidence readback shall be nondestructive except for an explicit destructive command defined by the Register Map. |
| RTLSTD-EVID-011 | Simultaneous source assertions shall preserve required source identity and priority. |
| RTLSTD-EVID-012 | Evidence assertions shall cover persistence, set/clear priority, no silent loss, overflow, ordering, and reset. |

## 22. Safety, Interlock, Watchdog, Lost-Link, and Output Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-SAFE-001 | Safety supervision shall operate in hardware without continuous host participation. |
| RTLSTD-SAFE-002 | Functional ownership of logical safety outputs shall match the Architecture and PBIO. No alternate direct drive path is permitted. |
| RTLSTD-SAFE-003 | Safety outputs and output enables shall implement the SRS and Architecture safe-state conditions. |
| RTLSTD-SAFE-004 | User logic, routing, debug, test, injection, or host transactions shall not bypass interlocks, fault latches, authorization, observational mode, or safe-state gating. |
| RTLSTD-SAFE-005 | Watchdog service, window, timeout, error, and response behavior shall define simultaneous-condition priority and preserve evidence. |
| RTLSTD-SAFE-006 | Interlock expressions and output paths shall be finite, validated, protected, and atomically activated as defined by the Register Map. |
| RTLSTD-SAFE-007 | Lost-link supervision shall implement the defined activity recognition, timeout, recovery qualification, evidence, and response behavior. |
| RTLSTD-SAFE-008 | Fault and safety response requests shall use finite encoded interfaces. Source modules shall not drive physical output pads directly. |
| RTLSTD-SAFE-009 | Observational mode shall permit the specified monitoring while inhibiting operational output activation. |
| RTLSTD-SAFE-010 | Invalid, malformed, unauthorized, or out-of-range safety configuration shall fail safely and create the required evidence. |
| RTLSTD-SAFE-011 | Safety state, clear, authorization, priority, and output gating shall be structured for formal proof. |
| RTLSTD-SAFE-012 | No test mode shall assert an operational safety output or suppress required fault evidence. |
| RTLSTD-SAFE-013 | Safety-response lane, source identifier, authorization bit, and requested-response fields shall use Architecture-owned generated types and constants. RTL shall not encode an alternate mask formula or locally maintained source table. |
| RTLSTD-SAFE-014 | Reserved safety-response source identifiers and reserved authorization bits shall be structurally unable to assert a request; configuration attempts to set reserved authorization bits shall follow the Register Map rejection contract without changing active authorization. |

## 23. Databus and Routing Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-BUS-001 | Databus RTL shall own only the digital protocol behavior allocated by the PBIO and Architecture. Electrical adaptation remains outside functional RTL. |
| RTLSTD-BUS-002 | Interface adaptation responsibilities shall match the Architecture; a downstream module shall not duplicate adapter behavior assigned to RTL-024 or another owner. |
| RTLSTD-BUS-003 | Routed messages shall use the Architecture-defined record and handshake. |
| RTLSTD-BUS-004 | Routing decisions shall depend only on defined configuration and message metadata. |
| RTLSTD-BUS-005 | Route and endpoint populations shall use the Architecture-controlled finite allocation. |
| RTLSTD-BUS-006 | Replication, arbitration, backpressure, filtering, rejection, queueing, and error evidence shall implement the Architecture-defined policy. |
| RTLSTD-BUS-007 | Configuration changes affecting active routing shall use the Register Map staging, validation, and commit mechanism. |
| RTLSTD-BUS-008 | Loop prevention, illegal endpoint rejection, and route-conflict behavior shall be explicit and verifiable. |
| RTLSTD-BUS-009 | Disabled transmitters and routes shall remain inactive and shall not consume or emit data. |
| RTLSTD-BUS-010 | Protocol status and event detail shall use the exact shared field and encoding definitions rather than module-local reinterpretation. |
| RTLSTD-BUS-011 | Queue overflow, underflow, malformed frame, adapter error, arbitration failure, and route rejection shall create the required evidence. |
| RTLSTD-BUS-012 | Protocol and routing assertions shall cover ordering, exact-once transfer, backpressure, filtering, arbitration, disabled behavior, and error paths. |

## 24. Centralized Shared Storage, Snapshot, and Commit Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-MEM-001 | RTL-024 shall instantiate the one Architecture-defined centralized shared-buffer service and shall expose it only through the typed request/response interfaces assigned to its seven clients. |
| RTLSTD-MEM-002 | RTL-017 through RTL-022 shall not instantiate private arrays, inferred RAMs, FIFOs, queues, or technology memories for payload entry storage covered by the centralized service. |
| RTLSTD-MEM-003 | Client modules shall retain only their Architecture-assigned queue semantics and control state, including pointers, occupancy, entry-valid state, sequencing, backpressure, overflow, underflow, and drop evidence. |
| RTLSTD-MEM-004 | Shared-buffer client identifiers, segment bases, segment limits, entry widths, entry counts, and reserved ranges shall come from `dfc_constants_pkg.sv`; numeric copies in client or RTL-024 source are prohibited. |
| RTLSTD-MEM-005 | Every client request shall use `dfc_types_pkg::dfc_buffer_req_t`, every response shall use `dfc_types_pkg::dfc_buffer_rsp_t`, and request/response stability shall follow the Architecture valid/ready contract. |
| RTLSTD-MEM-006 | A client shall issue only client-relative word offsets. RTL-024 shall derive the absolute address and reject every cross-segment, reserved-range, malformed, or excess-outstanding request without modifying storage. |
| RTLSTD-MEM-007 | No functional or test logic shall bypass arbitration, owner-range enforcement, response generation, or the typed client interfaces to read or write centralized storage. |
| RTLSTD-MEM-008 | Arbitration state shall implement rotating round-robin service, at most one accepted request per CORE_CLK, one outstanding request per client, the Architecture fairness bound, and the Architecture no-fault response-latency bound. |
| RTLSTD-MEM-009 | An entry owner shall complete every word write successfully before it advances the owner-local tail, count, or valid state that makes the entry observable. Partial or failed entry writes shall never become valid. |
| RTLSTD-MEM-010 | A reader shall issue entry reads only after owner-local valid state authorizes the complete entry. Physical contents from reset, an invalid entry, a canceled request, or a previously owned slot shall never be exposed as valid data. |
| RTLSTD-MEM-011 | System reset shall invalidate all client queue/mailbox state and reset arbitration. A module-scoped reset shall invalidate only that client's state and cancel its outstanding ownership as defined by the Architecture. Physical storage bits need not be cleared. |
| RTLSTD-MEM-012 | A canceled or stale response shall be consumed or discarded without advancing a pointer, changing occupancy, asserting valid, or modifying any unrelated client state. |
| RTLSTD-MEM-013 | Revision A centralized storage shall not add architectural ECC or parity. Technology storage wrappers may substitute BRAM, SRAM, or inferred memory only while preserving logical latency, ordering, read-during-write, reset-visibility, and error behavior. |
| RTLSTD-MEM-014 | RTL-005's Architecture-defined 64-entry, 128-bit event store is the sole register-array storage exception outside the centralized service and shall not be generalized into permission for other private payload stores. |
| RTLSTD-MEM-015 | RTL-005 shall implement mandatory overwrite-oldest behavior and the Architecture-defined nonrecursive, coalesced source-overflow and store-overflow reporting priority; no control bit may make overwrite policy configurable. |
| RTLSTD-MEM-016 | A snapshot shall remain stable until the exact replacement, pop, reset, or invalidation event defined by the Register Map. |
| RTLSTD-MEM-017 | Pop, destructive clear, validate, and commit shall require explicit accepted commands and shall not occur as incidental read side effects. |
| RTLSTD-MEM-018 | Staged configuration shall not affect active behavior before complete validation and a successful commit. |
| RTLSTD-MEM-019 | Memory test access shall remain bounded, use only the Architecture-defined production-test path, and remain inactive during normal operation. |
| RTLSTD-MEM-020 | Assertions shall cover client range protection, reserved-range rejection, request/response stability, outstanding limits, arbitration fairness, bounded response, entry atomic visibility, pointer/occupancy consistency, cancellation, reset visibility, overflow/underflow evidence, snapshot stability, and commit atomicity. |

## 25. User Logic and Configurable Routing Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-USER-001 | RTL-022 shall implement the fixed inert Revision A profile defined by the Architecture: no externally routed output message, user output requests and output enables inactive, nonzero functional parameters rejected, and diagnostic input capture permitted only through the defined mailbox path. |
| RTLSTD-USER-002 | User logic shall connect only to Architecture-defined interfaces and consumers. |
| RTLSTD-USER-003 | User logic shall not bypass protection, fault reporting, interlocks, safety gating, observational mode, test isolation, or product boundaries. |
| RTLSTD-USER-004 | Disabled or undefined user outputs shall assume the Architecture-defined safe state. |
| RTLSTD-USER-005 | Configurable routing shall select only from the finite Architecture-defined source and destination sets. |
| RTLSTD-USER-006 | Route changes shall use protected staging, validation, and commit semantics. |
| RTLSTD-USER-007 | Illegal endpoint use, route conflicts, loops, overflow, and rejected access shall create the defined evidence. |
| RTLSTD-USER-008 | User logic shall not create an undocumented clock, reset, host bus, debug path, processor, or expansion interface. |
| RTLSTD-USER-009 | User logic shall satisfy the same lint, simulation, formal, synthesis, CDC/RDC, and safety rules as other functional RTL. |
| RTLSTD-USER-010 | Route-entry counts, ready-signal conditions, and validation coverage shall use the single Architecture definition and shall not be locally restated. |
| RTLSTD-USER-011 | RTL-022 source shall not contain dormant programmable transformations, mask-selected mission behavior, alternate generate profiles, or fabrication-time parameters that can activate undefined output behavior. |
| RTLSTD-USER-012 | RTL-023 shall implement only the exact Architecture source/destination pair matrix, exclusivity, wired-OR, edge/level, disable, and activation-priority rules; safety, clock, reset, protected-write, and direct transmitter-control paths shall remain structurally unreachable. |

## 26. FPGA/ASIC Wrappers and Technology Isolation

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-WRAP-001 | FPGA and ASIC implementations shall use the same technology-independent Dragon Core functional RTL. |
| RTLSTD-WRAP-002 | FPGA-specific I/O, clock, reset, memory, and debug resources shall exist only in FPGA wrappers. |
| RTLSTD-WRAP-003 | ASIC pads, power, POR, identification, memory macros, clock/reset cells, scan/test cells, and physical implementation selections shall exist only in ASIC wrappers and the future ASIC Integration Specification; functional RTL shall depend only on the Architecture logical wrapper. |
| RTLSTD-WRAP-004 | Wrapper substitution shall preserve the SRS, Architecture, and Register Map observable behavior. |
| RTLSTD-WRAP-005 | Unused platform and user signals shall be tied deterministically. |
| RTLSTD-WRAP-006 | Logical pad interfaces shall use separate input, output, and output-enable signals. Internal core tri-states are prohibited. |
| RTLSTD-WRAP-007 | Prototype-only observability shall be bounded and disabled or absent in the production ASIC configuration. |
| RTLSTD-WRAP-008 | Technology wrappers shall state assumptions for reset, memory latency, clocks, pads, and test integration. |
| RTLSTD-WRAP-009 | Target differences shall be verified for behavioral correspondence. |
| RTLSTD-WRAP-010 | Technology-specific constraints shall remain outside functional source and shall reference the actual wrapper hierarchy. |
| RTLSTD-WRAP-011 | RTL-024 shall accept `core_clk_i` and internal platform-wrapper reset `por_n_i` exactly as defined by the Architecture. Source shall not create an external reset pad or assume that OpenFrame supplies a Dragon Core host bus or register interconnect. |
| RTLSTD-WRAP-012 | Platform wrappers shall adapt physical pads to RTL-024 input, output, and output-enable signals without changing logical polarity, safe state, qualification, ownership, or externally observable behavior. |

## 27. Synthesis, Timing, and Portability Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-SYN-001 | Every module shall synthesize in the selected generic and target flows without unresolved errors. |
| RTLSTD-SYN-002 | Latch inference, unintended memory, unintended clock gating, internal tri-states, combinational loops, multiple drivers, unresolved black boxes, and unsupported constructs are prohibited. |
| RTLSTD-SYN-003 | Inferred memories, arithmetic operators, counters, synchronizers, and FIFOs shall be reviewed for both FPGA and ASIC mapping. |
| RTLSTD-SYN-004 | Source behavior shall not depend on simulation/synthesis mismatch, declaration initialization, X optimism, X pessimism, event ordering, or unsupported pragmas. |
| RTLSTD-SYN-005 | Interface, timing, and safety paths shall be registered or otherwise analyzed to meet their owning requirements. |
| RTLSTD-SYN-006 | Constraints shall identify clocks, generated clocks created by Architecture-defined cells, I/O delays, asynchronous groups, synchronizers, false paths, and multicycle paths. |
| RTLSTD-SYN-007 | False-path and multicycle exceptions shall be minimal and shall match the actual transfer structure. |
| RTLSTD-SYN-008 | Warnings affecting width, signedness, truncation, latch, clock, reset, CDC/RDC, uninitialized state, unreachable logic, or optimization of required behavior shall be resolved or technically justified. |
| RTLSTD-SYN-009 | Resource use, timing, fanout, memory mapping, and wrapper mapping shall be reviewed at module and integration levels. |
| RTLSTD-SYN-010 | An FPGA-only capability shall not become a required dependency of the ASIC functional design. |
| RTLSTD-SYN-011 | Post-synthesis structural checks shall confirm absence of prohibited processors, software memories, open-ended fabric, and unintended debug paths. |
| RTLSTD-SYN-012 | Equivalence or targeted netlist checks shall be used when synthesis, wrapper substitution, memory mapping, or optimization could change observable behavior. |
| RTLSTD-SYN-013 | Timing constraints shall use measurement points and limits from the owning SRS or Architecture definition rather than copied values in scripts or comments. |
| RTLSTD-SYN-014 | A timing exception shall not be used to mask a functional CDC/RDC or handshake error. |

## 28. Production Test, Debug, and Security Boundaries

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-TEST-001 | Production test shall use only the bounded Architecture-defined interface and shall be inactive by default. |
| RTLSTD-TEST-002 | Test mode shall not assert operational safety outputs, bypass interlocks, clear required evidence, disable safe reset, or modify protected operational configuration outside defined test semantics. |
| RTLSTD-TEST-003 | Engineering observability and injection shall be compile-time controlled and disabled or absent in the production ASIC configuration unless part of the technical architecture. |
| RTLSTD-TEST-004 | Normal SPI register access shall remain the primary diagnostic interface. |
| RTLSTD-TEST-005 | Processor debug, firmware debug, hidden maintenance buses, and unrestricted scan-to-functional control are prohibited. |
| RTLSTD-TEST-006 | Protected register access shall not be represented as cryptographic authentication. |
| RTLSTD-TEST-007 | Secret-key storage, secure boot, cryptographic engines, or software trust anchors shall not be implied by implementation convenience. |
| RTLSTD-TEST-008 | Invalid or unauthorized test/debug requests shall create the specified result without prohibited side effects. |
| RTLSTD-TEST-009 | Test/debug signals shall be included in reset, CDC/RDC, pad, timing, synthesis, and negative-path verification. |
| RTLSTD-TEST-010 | Every enabled test/debug feature shall be visible in the build configuration and structurally checkable. |
| RTLSTD-TEST-011 | `test_active` shall assert only after the Architecture authorization sequence completes and shall deassert on reset, authorization loss, test-enable removal, malformed command, or the defined deauthorization condition. |
| RTLSTD-TEST-012 | CAPTURE, SHIFT, shift length, command arguments, capture-vector fields, and all eight loopback selections shall use Architecture-owned generated encodings and shall not be duplicated as local literals. |
| RTLSTD-TEST-013 | Production-test capture shall take one coherent Architecture-defined snapshot before shifting; functional signals shall not be sampled independently into the shift stream after capture. |
| RTLSTD-TEST-014 | Production-test loopbacks shall remain internal or fixture-safe and shall not activate a safety output, operational transmitter-control path, protected write, or functional configuration change. |
| RTLSTD-TEST-015 | Test command, status, capture, and shift logic shall implement the exact CDC/RDC ownership and reset rules associated with `CDC-TEST-001`, `CDC-TEST-002`, `CDC-TEST-003`, and `RDC-TEST-001`. |

## 29. Assertions, Formal Properties, and Verification Hooks

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-VER-001 | Protocol, state, reset, register, protection, CDC/RDC, FIFO, arbitration, evidence, and safety behavior shall be coded in a form suitable for assertions. |
| RTLSTD-VER-002 | Assertions may be embedded, bound, or placed in formal wrappers, but shall not modify synthesizable behavior. |
| RTLSTD-VER-003 | Formal assumptions shall be explicit, minimal, and limited to the true environment contract. |
| RTLSTD-VER-004 | Applicable properties shall cover protocol ordering, response uniqueness, no-side-effect rejection, reset-to-idle, protection, set-dominates-clear, evidence persistence, FIFO bounds, and output gating. |
| RTLSTD-VER-005 | Cover properties shall demonstrate reachability of required states, commands, simultaneous conditions, errors, and recovery paths. |
| RTLSTD-VER-006 | Verification hooks shall use existing interfaces or bounded bind points. Undocumented production ports added solely for testing are prohibited. |
| RTLSTD-VER-007 | Coverage points shall reference the controlling requirement, register object, interface, state, or error path rather than restating its definition. |
| RTLSTD-VER-008 | Simulation-only code shall be separated or guarded so both simulation and synthesis configurations compile cleanly. |
| RTLSTD-VER-009 | Randomization, BFMs, scoreboards, reference models, and file I/O belong in verification code. |
| RTLSTD-VER-010 | Module status and handshake behavior shall provide deterministic observability without creating an unrestricted debug interface. |
| RTLSTD-VER-011 | Assertion disables, formal bounds, proof assumptions, and coverage exclusions shall have a documented technical basis. |
| RTLSTD-VER-012 | Verification activity and evidence identifiers shall follow the Verification Plan without embedding lifecycle status in RTL. |

## 30. Static Conformance and Source Quality Rules

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-QA-001 | Every production source set shall pass syntax, type, compile, lint, elaboration, and applicable synthesis checks. |
| RTLSTD-QA-002 | Warnings shall be treated as technical findings until resolved or justified. |
| RTLSTD-QA-003 | Formatting shall use spaces, consistent indentation, one statement per line where practical, and reviewable line lengths. |
| RTLSTD-QA-004 | Production source shall contain no behavior-affecting `TODO`, `FIXME`, temporary stub, disabled block, incomplete alternate path, or temporary tie-off. Any missing behavior shall be corrected in its owning specification before implementation. |
| RTLSTD-QA-005 | Source conformance shall include interfaces, reset, CDC/RDC, register semantics, simultaneous conditions, safety, synthesizability, assertion support, and generated-data consistency. |
| RTLSTD-QA-006 | Module source shall identify its controlling module specification and Architecture module identity. |
| RTLSTD-QA-007 | Interface, clock, reset, register, safety-path, shared-buffer, wrapper, and shared-type source shall remain mechanically consistent with every directly consumed owning definition. |
| RTLSTD-QA-008 | Source, generated definitions, constraints, scripts, and tool settings shall be reproducible from the checked-in technical inputs. |
| RTLSTD-QA-009 | The active compile set shall contain one implementation of each module and one definition of each shared package. |
| RTLSTD-QA-010 | A technical fact shall not be copied into comments, assertions, test parameters, or constraints as an independently maintained value when it can be imported from its owning source. |
| RTLSTD-QA-011 | Source shall be free of unresolved width, signedness, latch, CDC/RDC, reset, multiple-driver, unused-state, and unreachable-code defects. |
| RTLSTD-QA-012 | Generated artifacts shall be regenerated and compared whenever an owning machine-readable definition changes. |

## 31. Mandatory Source-Conformance Requirements

The following are direct technical source requirements and carry no lifecycle status.

| Rule ID | Mandatory rule |
|---|---|
| RTLSTD-CONF-001 | Every module port, direction, type, width, producer, consumer, reset, and CDC/RDC treatment shall match the Architecture port and connectivity catalogs. |
| RTLSTD-CONF-002 | Register control, status, reset, access, validation, and side-effect logic shall match `dfc_registers_pkg.sv` and the Register Map. |
| RTLSTD-CONF-003 | Every state object shall have one procedural owner, a deterministic reset or specified retention rule, and explicit simultaneous-condition priority. |
| RTLSTD-CONF-004 | Every finite resource shall use its generated Architecture- or Register-Map-owned capacity, range, or allocation. |
| RTLSTD-CONF-005 | Production source shall contain no independently maintained copy of a normative constant, encoding, timing limit, address, field, packed width, source identifier, endpoint allocation, segment boundary, or port count. |
| RTLSTD-CONF-006 | Combinational logic shall be complete and latch free; sequential logic shall use explicit acceptance, reset, and update conditions. |
| RTLSTD-CONF-007 | Every valid/ready payload and mailbox object shall remain stable until the defined ownership or acceptance event. |
| RTLSTD-CONF-008 | Every CDC/RDC structure shall match an Architecture inventory entry and its assertions and constraints shall preserve that exact mechanism. |
| RTLSTD-CONF-009 | Rejected, malformed, unauthorized, timed-out, canceled, and reserved operations shall create no prohibited target or unrelated side effect. |
| RTLSTD-CONF-010 | Overflow, underflow, timeout, truncation, abort, dropped evidence, and internal error conditions shall remain observable exactly as specified. |
| RTLSTD-CONF-011 | Safety outputs and output enables shall remain inactive throughout reset, initialization, disable, global inhibit, observational operation where specified, and every production-test operation. |
| RTLSTD-CONF-012 | RTL-017 through RTL-022 shall contain no private centralized-service payload storage, and RTL-024 shall contain no client queue-policy state beyond its own SPI client. |
| RTLSTD-CONF-013 | RTL-024 shall elaborate as the complete logical integration top with exactly the Architecture-defined child instances, internal connections, wrapper-facing ports, and centralized service. |
| RTLSTD-CONF-014 | FPGA and ASIC wrappers shall preserve the same technology-independent functional behavior and shall not introduce a processor, private host bus, alternate register interconnect, or undocumented debug path. |
| RTLSTD-CONF-015 | Source shall compile, lint, elaborate, simulate, satisfy applicable formal properties, and synthesize without unresolved technical defects. |
| RTLSTD-CONF-016 | When source conformance depends on an absent, conflicting, ambiguous, or incomplete definition, implementation shall stop at that boundary until the owning specification is corrected. |

## Appendix A — Informative Coding Patterns

The examples below demonstrate structure only. Names, widths, reset values, encodings, and protocol constants shall come from the owning generated packages and module specification.

### A.1 Sequential state pattern

```systemverilog
always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
  if (!core_rst_n_i) begin
    state_q <= STATE_RESET;
  end else begin
    state_q <= state_d;
  end
end
```

### A.2 Combinational next-state pattern

```systemverilog
always_comb begin
  state_d = state_q;

  unique case (state_q)
    STATE_RESET: begin
      if (start_i) begin
        state_d = STATE_ACTIVE;
      end
    end

    STATE_ACTIVE: begin
      if (complete_i) begin
        state_d = STATE_IDLE;
      end
    end

    STATE_IDLE: begin
      if (start_i) begin
        state_d = STATE_ACTIVE;
      end
    end

    default: begin
      state_d = STATE_RESET;
    end
  endcase
end
```

### A.3 Set-dominates-clear pattern

```systemverilog
always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
  if (!core_rst_n_i) begin
    evidence_q <= 1'b0;
  end else begin
    if (new_evidence_i) begin
      evidence_q <= 1'b1;
    end else if (clear_evidence_i) begin
      evidence_q <= 1'b0;
    end
  end
end
```

### A.4 Valid/ready payload stability property

```systemverilog
assert property (@(posedge core_clk_i) disable iff (!core_rst_n_i)
  valid_o && !ready_i |=> valid_o && $stable(payload_o));
```

### A.5 Exact-once acceptance property

```systemverilog
logic accept;
assign accept = valid_i && ready_o;

assert property (@(posedge core_clk_i) disable iff (!core_rst_n_i)
  accept |-> !duplicate_accept_condition);
```

### A.6 Generated-definition use

```systemverilog
dfc_types_pkg::dfc_event_record_t event_q;
dfc_types_pkg::dfc_buffer_req_t   buffer_req_q;

assign event_o      = event_q;
assign buffer_req_o = buffer_req_q;
```

The example uses package qualification so the shared type owner remains visible. Generated register constants and Architecture allocations shall be referenced in the same manner; literal values shall not be copied from prose into implementation source.
