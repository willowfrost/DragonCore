# Dragon Core Register Map Specification

- **Document ID:** RCA-DFC-REG-002
- **Product:** Dragon Core Revision A
- **Organization:** Royal Cubit Aerospace
- **Purpose:** Define the complete transport-independent host-visible register contract.

## 1. Purpose and Scope

This specification is the sole normative owner of Dragon Core host-visible register offsets, register and field names, access classes, reset values, legal encodings, validation, read behavior, write behavior, and side effects, as assigned by `RCA-DFC-CHTR-002`, Section 3.1 and `PBIO-REG-005`.

It defines the logical 32-bit register contract consumed through the Architecture-defined SPI and Dragon Register Interface (DRI). It does not redefine SPI framing, DRI timing, module algorithms, internal packed types, source allocations, CDC/RDC, or verification methods. Those facts remain owned by their cited Architecture, SRS, or Verification Plan identifiers.

Every field is referenced as `REGISTER.FIELD`. Every register has the stable contract identifier `REG-` followed by its four-digit hexadecimal address. Unimplemented addresses have no register identifier.

## 2. Normative Register Rules

| ID | Rule |
|---|---|
| REG-GEN-001 | Registers are 32-bit words addressed by 32-bit byte offsets from the Dragon Core logical register origin and aligned to four-byte boundaries. |
| REG-GEN-002 | Revision A accepts only full-word writes with DRI byte strobes `4'b1111`; every partial write returns ACCESS_ERROR with no side effect. |
| REG-GEN-003 | Bit 0 is the least-significant bit. For a multiword scalar, the least-significant word occupies the lower address. SPI byte order does not change logical field numbering. |
| REG-GEN-004 | Reads are nondestructive. No register has read-to-clear behavior. Snapshot and pop are distinct operations. |
| REG-GEN-005 | A write is atomic at one register word. A write containing any invalid field, reserved one, illegal combination, failed authorization, or unmet command precondition is rejected in full. |
| REG-GEN-006 | Multiword host commands are ordered and non-atomic; execution stops at the first failing word. Only an explicit staging/commit object provides atomic multi-register activation. |
| REG-GEN-007 | Reset, disable, safety inhibit, accepted commit/command, newly detected condition, authorized clear, then ordinary progression is the default priority. A more specific Architecture contract may specialize ordinary progression but shall preserve safety/reset dominance. |
| REG-GEN-008 | New sticky evidence dominates a simultaneous clear of the same evidence. For a saturating counter, a simultaneous qualifying increment dominates a whole-counter clear. |
| REG-GEN-009 | Unimplemented aligned addresses return DRI DECODE_ERROR. Unaligned addresses are rejected before DRI. Reserved fields read zero. |
| REG-GEN-010 | A successful state-changing DRI write commits only with its OK response. A timeout cannot cause a late or untracked write. |
| REG-GEN-011 | Configuration stored in RTL-001 remains volatile. Module reset preserves it unless the reset scope includes RTL-001; system or external reset restores every field reset value. |
| REG-GEN-012 | All safety outputs remain inactive during reset, initialization, disable, global inhibit, observational mode, invalid state, and every production-test operation. No register is a direct safety-output command. |

## 3. Field Access Classes

| Access | Read behavior | Write behavior |
|---|---|---|
| RW | Stored active or staged value | Legal full-word write atomically updates the field |
| RO | Current coherent hardware value | Any write intended to change the field is ACCESS_ERROR |
| WO-CMD | Zero | Legal nonzero command encoding emits one bounded one-cycle command; zero has no effect unless stated |
| W1C | Current sticky or mask value | One requests bit clear; zero has no effect; new evidence dominates |
| W1S | Current separately exposed set state | One sets or acknowledges the selected bit; zero has no effect |
| COUNTER-CLR | Current 32-bit saturating counter | Word `0x00000000` has no effect; `0xFFFFFFFF` emits one whole-counter clear pulse; any other word is ACCESS_ERROR |
| CONST | Fixed product/build parameter | Write is ACCESS_ERROR |
| CONST1 | Fixed one in a mixed register | Host must preserve one; writing zero rejects the entire word |
| RSV0 | Zero | Host must write zero; writing one rejects the entire word |

## 4. Protection, Errors, and Transaction Evidence

The protected-write sequence is two consecutive accepted writes to `PROTECT_KEY.KEY`: `0x52434131`, then `0x4452474E`, followed by exactly one protected write within 50,000 CORE_CLK cycles. Authorization clears on reset, successful protected write, bad key, malformed access, CRC failure, timeout, pre-acceptance abort, or unauthorized protected access. These constants provide deterministic hardware authorization and are not cryptographic secrets.

The first-error validation order is alignment, decode, access class, reserved bits, field range/encoding, cross-field relation, protection, resource state/busy, then endpoint completion. Failure preserves all target state and records the applicable status. Pre-acceptance abort sets `HOST_STATUS.ABORTED` and increments `HOST_ABORT_COUNT.COUNT` but does not alter `HOST_LAST_RESULT`, `HOST_LAST_SEQUENCE`, or `HOST_LAST_ADDRESS`. Post-acceptance response truncation sets `HOST_STATUS.RESPONSE_TRUNCATED` and increments the same abort counter without rolling back a completed word or changing its terminal result.

## 5. Legal Encodings and Cross-Field Validation

The following Register-Map rules are normative for host values. Architecture identifiers identify the algorithms and allocations from which the constraints are derived.

| ID | Register validation rule | Architecture source |
|---|---|---|
| REG-ENC-001 | `SUBSYS_ENABLE.ENABLE[23:0]`: mandatory bits 0, 1, 3, 4, 11-15, and 23 read one and cannot be cleared; only optional bits 5-10 and 16-22 are configurable. | ARCH-VAL-002 |
| REG-ENC-002 | `CONDITION_MASK_SELECT.RTL_INDEX` is 0-23. For the selected module, only condition bits listed by Architecture Appendix F.3 may be one; unlisted bits reject the applicable mask write. | ARCH-VAL-001; Appendix F.3 |
| REG-ENC-003 | Interrupt enable, acknowledge, clear, and test-injection masks may set only bits 0-23. Bits 24-31 are reserved zero. | ARCH-VAL-003; Appendix C.4 |
| REG-ENC-004 | The raw timestamp is always enabled. The signed 64-bit two's-complement correlation offset accepts every bit pattern; commit requires both staged words and protection. | ARCH-VAL-004; ARCH-TIME-001 through ARCH-TIME-006 |
| REG-ENC-005 | Event overwrite-oldest is constant enabled. Event source masks may set only bits 0-23. `EVT_POP.POP` requires a valid snapshot and nonempty store; `EVT_SNAPSHOT.CAPTURE_OLDEST` requires nonempty. | ARCH-VAL-005; ARCH-EVT-001 through ARCH-EVT-008 |
| REG-ENC-006 | CAN timing uses `BRP=PRESCALER_MINUS_1+1`, `TSEG1=TSEG1_MINUS_1+1`, `TSEG2=TSEG2_MINUS_1+1`, `SJW=SJW_MINUS_1+1`; total quanta 8-25, TSEG1 2-16, TSEG2 1-8, SJW 1-min(4,TSEG2), bit rate <=1 MHz, requested-rate error <=1%. LOOPBACK/LISTEN_ONLY=`11` is illegal. DLC is 0-8; standard IDs have bits 28:11 zero; RTR data words are zero. | ARCH-BUS-003; ARCH-VAL-019 |
| REG-ENC-007 | UART divisor is `round(50,000,000/baud)`, legal 50-50,000, reset 434. Parity 0 none, 1 even, 2 odd; 3 is reserved. RX error flags are framing, parity, overrun, break, shared-buffer error in bits 0-4; bits 5-7 are zero. | ARCH-BUS-004; ARCH-VAL-020 |
| REG-ENC-008 | ARINC uses odd parity. RX/TX speed is low or high. TX gap is 4-255 bit times. TX parity override is legal only when AUTO_PARITY=0 and override-valid=1. Error codes are 0 none, 1 parity, 2 framing/gap, 3 RX overrun, 4 TX underrun, 5 adapter, 6 disabled, 7 invalid configuration, 8 shared-buffer; 9-0xFFF reserved. | ARCH-BUS-001; ARCH-BUS-002; ARCH-VAL-017; ARCH-VAL-018 |
| REG-ENC-009 | Routing source IDs are 0-4, destination masks use bits 0-4 and are nonzero for an enabled route, type masks use only bits 0-4 for message types 0x01, 0x02, 0x04, 0x08, 0x10, and the fixed 5x5 Architecture authorization matrix applies. | ARCH-MSG-001 through ARCH-MSG-005; ARCH-ROUTE-001 through ARCH-ROUTE-008 |
| REG-ENC-010 | Interlock terms are IDs 0-31 or 37. Operators are 0 AND, 1 OR, 2 three-of-four, 3 `(t0&t1)\|(t2&t3)`. Enabled entries require nonzero guard mask; all eight staged entries validate before COMMIT_ALL. | ARCH-SAFE-006; Appendix C.3; ARCH-VAL-014 |
| REG-ENC-011 | Monitor constraints are: rotor `0<=LOW<=HIGH<=1000`; engine `0<=LOW<=HIGH<=20000`; PPR 1-65535 when enabled; qualification 0-100 ms; nonzero timeout when enabled; Q17.15 pulse range 0.5-100,000 Hz; hysteresis is nonnegative and no greater than HIGH-LOW. | ARCH-VAL-006 through ARCH-VAL-009 |
| REG-ENC-012 | Sensor values and thresholds are signed 32-bit two's-complement. Signed LOW<=HIGH; hysteresis is nonnegative and no greater than the signed interval without overflow; source 0-127; sequence 24 bits. Host commit wins over a simultaneous routed update. | ARCH-MON-006; ARCH-MON-007; ARCH-VAL-010 |
| REG-ENC-013 | Watchdog MIN_WINDOW_US is less than nonzero MAX_WINDOW_US. Service key is exact. Fault masks may set only bits 0-16; recoverability is fixed `0x00017FEF`. | ARCH-VAL-012; ARCH-VAL-013; Appendix C.6 |
| REG-ENC-014 | Lost-link monitor 0-7, activity source 0-7, QUALIFY_US<TIMEOUT_US, nonzero timeout and recovery interval, and response mask bits 0-3 are required. | ARCH-VAL-015 |
| REG-ENC-015 | `SAFETY_RESPONSE_MASK.RESPONSE_SOURCE_MASK` may set only bits 0, 8, and 16-31 (`0xFFFF0101`). Bits 1-7 and 9-15 are reserved and reject the entire write. A disabled channel requires a zero response mask. | ARCH-SAFE-001 through ARCH-SAFE-004; Appendix C.8; ARCH-VAL-016 |
| REG-ENC-016 | Production-test opcodes are 0x01 CAPTURE, 0x02 SHIFT, 0x03 SAFE_LOOPBACK. CAPTURE argument is zero. SHIFT uses argument bits 8:0 length-minus-one and bits 23:9 zero. SAFE_LOOPBACK uses select bits 2:0, enable bit 3, bits 23:4 zero. Loopback select is 0-7. | ARCH-TEST-001 through ARCH-TEST-016 |
| REG-ENC-017 | RTL-022 Revision A functional enable, parameters, operational output requests, and operational message generation have the sole legal value zero. Nonzero writes are rejected. Diagnostic mailbox commands remain legal subject to full/empty state. | ARCH-ULI-001 through ARCH-ULI-005; ARCH-VAL-022 |
| REG-ENC-018 | User-route source IDs are 0-31 or 37 and destinations 0-24, subject to the exact Architecture source/destination pair matrix. Modes are 0 level, 1 rising pulse, 2 falling pulse, 3 either-edge pulse. Complete-bank conflict and exclusivity checks occur at commit. | ARCH-VAL-023; Architecture Section 13.2 |
| REG-ENC-019 | `RESET_CONTROL` accepts zero (no action) or exactly one of SYSTEM_RESET, one MODULE_RESET bit for RTL-001 through RTL-024, or SAFETY_DOMAIN_RESET. Multiple scopes reject atomically. `HOST_LAST_RESULT.SPI_STATUS` uses SRS values 0x00-0x0A only; DRI_CODE uses Architecture values 0-6; OPCODE is 0x01 READ or 0x02 WRITE. | ARCH-RST-004 through ARCH-RST-006; ARCH-DRI-008; ARCH-SPI-002 |

## 6. Address-Map Summary

| Range | Block | Primary owner | Registers |
|---|---|---|---:|
| 0x0000-0x00FF | Identification, System Control, Protection, and Configuration Errors | RTL-001 / RTL-002 | 24 |
| 0x0100-0x01FF | Interrupt Controller | RTL-003 | 8 |
| 0x0200-0x02FF | Timestamp Engine | RTL-004 | 10 |
| 0x0300-0x03FF | Event Logger | RTL-005 | 14 |
| 0x0400-0x04FF | GPIO Controller | RTL-006 | 14 |
| 0x0500-0x05FF | Host and Integration Diagnostics | RTL-024 / RTL-001 | 12 |
| 0x0600-0x06FF | Production Test | RTL-024 / ASIC integration wrapper | 6 |
| 0x1000-0x10FF | ARINC 429 Receive | RTL-017 / RTL-024 receive adapter | 12 |
| 0x1100-0x11FF | ARINC 429 Transmit | RTL-018 | 10 |
| 0x1200-0x12FF | Classical CAN | RTL-019 | 21 |
| 0x1300-0x13FF | UART | RTL-020 | 11 |
| 0x1400-0x14FF | Databus Routing Engine | RTL-021 | 17 |
| 0x2000-0x20FF | Rotor RPM Monitor | RTL-007 | 11 |
| 0x2100-0x21FF | Engine RPM Monitor | RTL-008 | 11 |
| 0x2200-0x22FF | Pulse/Frequency Measurement | RTL-009 | 19 |
| 0x2300-0x23FF | Sensor Monitor Interface | RTL-010 | 25 |
| 0x2400-0x24FF | System Health Monitor | RTL-011 | 13 |
| 0x3000-0x30FF | Watchdog Manager | RTL-012 | 8 |
| 0x3100-0x31FF | Fault Manager | RTL-013 | 9 |
| 0x3200-0x32FF | Interlock Engine | RTL-014 | 10 |
| 0x3300-0x33FF | Lost-Link Supervisor | RTL-015 | 10 |
| 0x3400-0x34FF | Safety Output Controller | RTL-016 | 8 |
| 0x4000-0x40FF | Mask-Defined User Logic Island | RTL-022 | 20 |
| 0x4100-0x41FF | User-Configurable Routing Logic | RTL-023 | 11 |

The address map contains **314 implemented 32-bit registers**. Every other aligned address is unimplemented and returns DECODE_ERROR; address gaps do not reserve an expansion function.

## 7. Identification, System Control, Protection, and Configuration Errors

Product identification, operating controls, reset commands, protected-write authorization, configuration-error evidence, and per-module condition-mask programming.

| Attribute | Value |
|---|---|
| Address range | 0x0000-0x00FF |
| Primary owner | RTL-001 / RTL-002 |
| Register count | 24 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x0000` | `DFC_DEVICE_ID` | `REG-0000` |
| `0x0004` | `DFC_PRODUCT_REV` | `REG-0004` |
| `0x0008` | `DFC_REGMAP_REV` | `REG-0008` |
| `0x000C` | `DFC_BUILD_ID` | `REG-000C` |
| `0x0010` | `DFC_CAPABILITY0` | `REG-0010` |
| `0x0014` | `SYS_CONTROL` | `REG-0014` |
| `0x0018` | `SYS_STATUS` | `REG-0018` |
| `0x001C` | `SUBSYS_ENABLE` | `REG-001C` |
| `0x0020` | `SUBSYS_READY` | `REG-0020` |
| `0x0024` | `SUBSYS_FAULT` | `REG-0024` |
| `0x0028` | `RESET_CONTROL` | `REG-0028` |
| `0x002C` | `RESET_STATUS` | `REG-002C` |
| `0x0030` | `PROTECT_KEY` | `REG-0030` |
| `0x0034` | `PROTECT_STATUS` | `REG-0034` |
| `0x0038` | `CONFIG_ERROR_STATUS` | `REG-0038` |
| `0x003C` | `CONFIG_ERROR_ADDR` | `REG-003C` |
| `0x0040` | `CONFIG_ERROR_DATA` | `REG-0040` |
| `0x0044` | `RTL002_EVT_OVERFLOW_STATUS` | `REG-0044` |
| `0x0048` | `RTL001_EVT_OVERFLOW_STATUS` | `REG-0048` |
| `0x004C` | `CONDITION_MASK_SELECT` | `REG-004C` |
| `0x0050` | `EVENT_CONDITION_MASK_LO` | `REG-0050` |
| `0x0054` | `EVENT_CONDITION_MASK_HI` | `REG-0054` |
| `0x0058` | `IRQ_CONDITION_MASK_LO` | `REG-0058` |
| `0x005C` | `IRQ_CONDITION_MASK_HI` | `REG-005C` |

### DFC_DEVICE_ID (`0x0000`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0000` |
| Access summary | CONST |
| Register reset | 0x44464331 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Dragon Flight Core product identifier. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `DEVICE_ID` | CONST | 0x44464331 | Fixed reset/read value | Any register write is ACCESS_ERROR | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### DFC_PRODUCT_REV (`0x0004`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0004` |
| Access summary | CONST |
| Register reset | 0x00010000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Product major/minor revision, Revision A = 1.0. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:16 | `MAJOR` | CONST | 0x0001 | Fixed reset/read value | Any register write is ACCESS_ERROR | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 15:0 | `MINOR` | CONST | 0x0000 | Fixed reset/read value | Any register write is ACCESS_ERROR | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### DFC_REGMAP_REV (`0x0008`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0008` |
| Access summary | CONST |
| Register reset | 0x00030001 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Register-contract semantic version: major 3, minor 1. It identifies the programming model and contains no document-history state. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:16 | `MAJOR` | CONST | 0x0003 | Fixed reset/read value | Any register write is ACCESS_ERROR | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 15:0 | `MINOR` | CONST | 0x0001 | Fixed reset/read value | Any register write is ACCESS_ERROR | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### DFC_BUILD_ID (`0x000C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-000C` |
| Access summary | CONST |
| Register reset | BUILD_ID parameter (default 0x00000000) |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Implementation build identifier supplied by the generated build parameter BUILD_ID and recorded in the build manifest; it is not derived from a document date or revision. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `BUILD_ID` | CONST | BUILD_ID parameter | Fixed reset/read value | Any register write is ACCESS_ERROR | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### DFC_CAPABILITY0 (`0x0010`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0010` |
| Access summary | Mixed: CONST, RSV0 |
| Register reset | 0x00FFFFFF |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Presence bitmap for RTL-001 through RTL-024. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 23:0 | `MODULE_PRESENT` | CONST | 0xFFFFFF | Fixed reset/read value | Any register write is ACCESS_ERROR | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 31:24 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### SYS_CONTROL (`0x0014`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0014` |
| Access summary | Mixed: RW, WO-CMD, RSV0 |
| Register reset | 0x0000000A |
| Owner | RTL-001 / RTL-002 |
| Protection | Yes for bits 0-3 |
| Register behavior | Global operational controls and mode selection. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `OPERATIONAL_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 1 | `OBSERVATIONAL_MODE` | RW | 1 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 2 | `GLOBAL_IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 3 | `GLOBAL_EVENT_ENABLE` | RW | 1 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 4 | `DEGRADED_ACK` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one DEGRADED_ACK command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |

### SYS_STATUS (`0x0018`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0018` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000041 |
| Owner | RTL-002 |
| Protection | No |
| Register behavior | Current operating-state and startup summary. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `RESET_ACTIVE` | RO | 1 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 1 | `STARTUP` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 2 | `HOST_READY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 3 | `NORMAL` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 4 | `DEGRADED` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 5 | `FAULTED` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 6 | `OBSERVATIONAL` | RO | 1 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 7 | `TEST_DEBUG` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 8 | `INIT_COMPLETE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 9 | `INIT_FAILED` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 31:10 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |

### SUBSYS_ENABLE (`0x001C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-001C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x0080F81F |
| Owner | RTL-001 / RTL-002 |
| Protection | Yes for configurable bits |
| Register behavior | Enable bitmap for RTL-001 through RTL-024. Fixed mandatory mask 0x80F81F is enabled; only optional mask 0x7F07E0 is configurable. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 23:0 | `ENABLE` | RW | 0x80F81F | Any defined 24-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 31:24 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |

### SUBSYS_READY (`0x0020`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0020` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-002 |
| Protection | No |
| Register behavior | Readiness bitmap for RTL-001 through RTL-024. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 23:0 | `READY` | RO | 0x000000 | Any defined 24-bit subset; reserved source bits zero | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 31:24 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |

### SUBSYS_FAULT (`0x0024`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0024` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-002 |
| Protection | No |
| Register behavior | Fault or initialization-failure bitmap for RTL-001 through RTL-024. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 23:0 | `FAULT` | RO | 0x000000 | Any defined 24-bit subset; reserved source bits zero | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 31:24 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |

### RESET_CONTROL (`0x0028`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0028` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-002 |
| Protection | Yes |
| Register behavior | Protected reset-request command. |
| Register-level side effect | Qualified reset request; reads return zero. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `SYSTEM_RESET` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Qualified reset request; reads return zero. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 24:1 | `MODULE_RESET` | WO-CMD | 0x000000 | Zero or exactly one bit for RTL-001 through RTL-024 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Qualified reset request; reads return zero. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 25 | `SAFETY_DOMAIN_RESET` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Qualified reset request; reads return zero. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 31:26 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |

### RESET_STATUS (`0x002C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-002C` |
| Access summary | Mixed: RO, W1C |
| Register reset | 0x00000000 |
| Owner | RTL-002 |
| Protection | No |
| Register behavior | Reset busy, completion, rejection, and scope status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `BUSY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 1 | `COMPLETE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 2 | `REJECTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 26:3 | `LAST_SCOPE` | RO | 0x000000 | Any defined 24-bit subset; reserved source bits zero | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 31:27 | `LAST_RESULT` | RO | 0x00 | 0-0x1F | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |

### PROTECT_KEY (`0x0030`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0030` |
| Access summary | WO-CMD |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Protected-write authorization key input. |
| Register-level side effect | Advances or cancels authorization state; reads zero. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `KEY` | WO-CMD | 0x00000000 | 0-0xFFFFFFFF | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Advances or cancels authorization state; reads zero. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### PROTECT_STATUS (`0x0034`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0034` |
| Access summary | Mixed: W1C, RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Protected-write authorization and failure status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `KEY1_ACCEPTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 1 | `ARMED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 2 | `EXPIRED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 3 | `BAD_KEY` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 4 | `UNAUTHORIZED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 20:5 | `REMAINING_CYCLES` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 31:21 | `RSV0` | RSV0 | 0x000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### CONFIG_ERROR_STATUS (`0x0038`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0038` |
| Access summary | Mixed: W1C, RO |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Sticky configuration and register-access rejection status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `INVALID_ADDRESS` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 1 | `UNALIGNED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 2 | `ACCESS_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 3 | `PROTECTED_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 4 | `ENDPOINT_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 5 | `TIMEOUT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 6 | `CRC_OR_FRAME` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 7 | `MULTIPLE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 31:8 | `COUNT` | RO | 0x000000 | 0-0xFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### CONFIG_ERROR_ADDR (`0x003C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-003C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Byte offset associated with the first retained configuration error. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `ADDRESS` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### CONFIG_ERROR_DATA (`0x0040`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0040` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Write data or command value associated with the first retained error. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `WRITE_DATA` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### RTL002_EVT_OVERFLOW_STATUS (`0x0044`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0044` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-002 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-002, ARCH-RTL002-001, ARCH-VAL-002 |

### RTL001_EVT_OVERFLOW_STATUS (`0x0048`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0048` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### CONDITION_MASK_SELECT (`0x004C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-004C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Selects RTL index 0-23 for the four condition-mask data registers. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 4:0 | `RTL_INDEX` | RW | 0x00 | 0-23 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### EVENT_CONDITION_MASK_LO (`0x0050`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0050` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Selected module event-condition enable mask bits 31:0. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MASK` | RW | 0x00000000 | Any defined 32-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### EVENT_CONDITION_MASK_HI (`0x0054`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0054` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Selected module event-condition enable mask bits 63:32. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MASK` | RW | 0x00000000 | Any defined 32-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### IRQ_CONDITION_MASK_LO (`0x0058`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0058` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Selected module interrupt-condition enable mask bits 31:0. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MASK` | RW | 0x00000000 | Any defined 32-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

### IRQ_CONDITION_MASK_HI (`0x005C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-005C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 |
| Protection | No |
| Register behavior | Selected module interrupt-condition enable mask bits 63:32. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MASK` | RW | 0x00000000 | Any defined 32-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001 |

## 8. Interrupt Controller

Fixed-source interrupt enable, raw, pending, acknowledgement, clear, and priority-vector registers.

| Attribute | Value |
|---|---|
| Address range | 0x0100-0x01FF |
| Primary owner | RTL-003 |
| Register count | 8 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x0100` | `IRQ_ENABLE` | `REG-0100` |
| `0x0104` | `IRQ_RAW_STATUS` | `REG-0104` |
| `0x0108` | `IRQ_PENDING` | `REG-0108` |
| `0x010C` | `IRQ_ACK` | `REG-010C` |
| `0x0110` | `IRQ_ACKED` | `REG-0110` |
| `0x0114` | `IRQ_CLEAR` | `REG-0114` |
| `0x0118` | `IRQ_VECTOR` | `REG-0118` |
| `0x011C` | `RTL003_EVT_OVERFLOW_STATUS` | `REG-011C` |

### IRQ_ENABLE (`0x0100`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0100` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-003 |
| Protection | No |
| Register behavior | Per-source interrupt enable mask. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `ENABLE` | RW | 0x00000000 | Any defined 32-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |

### IRQ_RAW_STATUS (`0x0104`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0104` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-003 |
| Protection | No |
| Register behavior | Latched raw source evidence independent of enables. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `RAW_STATUS` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |

### IRQ_PENDING (`0x0108`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0108` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-003 |
| Protection | No |
| Register behavior | Enabled pending source bitmap. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PENDING` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |

### IRQ_ACK (`0x010C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-010C` |
| Access summary | WO-CMD |
| Register reset | 0x00000000 |
| Owner | RTL-003 |
| Protection | No |
| Register behavior | Acknowledges service of selected pending sources. |
| Register-level side effect | Sets corresponding IRQ_ACKED bits; does not clear raw evidence. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `ACK_SET` | WO-CMD | 0x00000000 | 0-0xFFFFFFFF | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Sets corresponding IRQ_ACKED bits; does not clear raw evidence. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |

### IRQ_ACKED (`0x0110`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0110` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-003 |
| Protection | No |
| Register behavior | Acknowledged-source bitmap. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `ACKED` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |

### IRQ_CLEAR (`0x0114`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0114` |
| Access summary | W1C |
| Register reset | 0x00000000 |
| Owner | RTL-003 |
| Protection | No |
| Register behavior | Clears acknowledged, clearable source evidence. |
| Register-level side effect | Only acknowledged clearable evidence clears; active levels remain or reassert. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `CLEAR` | W1C | 0x00000000 | 0-0xFFFFFFFF | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |

### IRQ_VECTOR (`0x0118`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0118` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-003 |
| Protection | No |
| Register behavior | Encoded lowest-numbered enabled pending source. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 4:0 | `SOURCE` | RO | 0x00 | 0-23 when VALID=1; 0 when VALID=0 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |
| 30:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |
| 31 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |

### RTL003_EVT_OVERFLOW_STATUS (`0x011C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-011C` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-003 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003 |

## 9. Timestamp Engine

Always-running raw time, coherent snapshots, signed correlation staging, and atomic correlation commit.

| Attribute | Value |
|---|---|
| Address range | 0x0200-0x02FF |
| Primary owner | RTL-004 |
| Register count | 10 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x0200` | `TIME_CONTROL` | `REG-0200` |
| `0x0204` | `TIME_STATUS` | `REG-0204` |
| `0x0208` | `TIME_SNAPSHOT` | `REG-0208` |
| `0x020C` | `TIME_RAW_LO` | `REG-020C` |
| `0x0210` | `TIME_RAW_HI` | `REG-0210` |
| `0x0214` | `TIME_SYNC_OFFSET_LO` | `REG-0214` |
| `0x0218` | `TIME_SYNC_OFFSET_HI` | `REG-0218` |
| `0x021C` | `TIME_SYNC_COMMIT` | `REG-021C` |
| `0x0220` | `TIME_SYNC_STATUS` | `REG-0220` |
| `0x0224` | `RTL004_EVT_OVERFLOW_STATUS` | `REG-0224` |

### TIME_CONTROL (`0x0200`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0200` |
| Access summary | Mixed: CONST1, RW, RSV0 |
| Register reset | 0x00000001 |
| Owner | RTL-004 |
| Protection | Yes for CORRELATION_ENABLE; ENABLE is constant one |
| Register behavior | Always-running raw timestamp control and independently configurable correlation enable. ENABLE reads one and cannot be cleared. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | CONST1 | 1 | 1 only | Host writes one; zero rejects the entire mixed-register write | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 1 | `CORRELATION_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 31:2 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |

### TIME_STATUS (`0x0204`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0204` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000001 |
| Owner | RTL-004 |
| Protection | No |
| Register behavior | Timestamp running, snapshot, synchronization, and error status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `RUNNING` | RO | 1 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 1 | `SNAPSHOT_VALID` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 2 | `SYNC_VALID` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 3 | `SYNC_UPDATED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 4 | `ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |

### TIME_SNAPSHOT (`0x0208`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0208` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-004 |
| Protection | No |
| Register behavior | Captures the current raw timestamp into TIME_RAW_LO/HI. |
| Register-level side effect | Snapshot capture; reads zero. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `CAPTURE` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Snapshot capture; reads zero. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |

### TIME_RAW_LO (`0x020C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-020C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-004 |
| Protection | No |
| Register behavior | Snapshot timestamp bits 31:0. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `RAW_LO` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |

### TIME_RAW_HI (`0x0210`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0210` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-004 |
| Protection | No |
| Register behavior | Snapshot timestamp bits 63:32. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `RAW_HI` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |

### TIME_SYNC_OFFSET_LO (`0x0214`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0214` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-004 |
| Protection | Yes |
| Register behavior | Staged host-correlation offset bits 31:0. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `OFFSET_LO` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |

### TIME_SYNC_OFFSET_HI (`0x0218`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0218` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-004 |
| Protection | Yes |
| Register behavior | Staged host-correlation offset bits 63:32. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `OFFSET_HI` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |

### TIME_SYNC_COMMIT (`0x021C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-021C` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-004 |
| Protection | Yes |
| Register behavior | Atomically commits the staged correlation offset. |
| Register-level side effect | Commits offset; raw counter is not changed. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `COMMIT` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Commits offset; raw counter is not changed. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |

### TIME_SYNC_STATUS (`0x0220`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0220` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-004 |
| Protection | No |
| Register behavior | Active correlation-offset status and update sequence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `UPDATE_SEQUENCE` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 16 | `ACTIVE_VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 31:17 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |

### RTL004_EVT_OVERFLOW_STATUS (`0x0224`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0224` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-004 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-004, ARCH-RTL004-001, ARCH-VAL-004 |

## 10. Event Logger

Nondestructive snapshot and explicit pop access to the fixed 64-record event store, including mandatory overwrite-oldest evidence.

| Attribute | Value |
|---|---|
| Address range | 0x0300-0x03FF |
| Primary owner | RTL-005 |
| Register count | 14 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x0300` | `EVT_CONTROL` | `REG-0300` |
| `0x0304` | `EVT_STATUS` | `REG-0304` |
| `0x0308` | `EVT_COUNT` | `REG-0308` |
| `0x030C` | `EVT_OVERFLOW_COUNT` | `REG-030C` |
| `0x0310` | `EVT_SOURCE_ENABLE` | `REG-0310` |
| `0x0314` | `EVT_SNAPSHOT` | `REG-0314` |
| `0x0318` | `EVT_DATA0` | `REG-0318` |
| `0x031C` | `EVT_DATA1` | `REG-031C` |
| `0x0320` | `EVT_DATA2` | `REG-0320` |
| `0x0324` | `EVT_DATA3` | `REG-0324` |
| `0x0328` | `EVT_POP` | `REG-0328` |
| `0x032C` | `EVT_CLEAR` | `REG-032C` |
| `0x0330` | `EVT_DROP_SOURCE` | `REG-0330` |
| `0x0334` | `EVT_ARB_STATUS` | `REG-0334` |

### EVT_CONTROL (`0x0300`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0300` |
| Access summary | Mixed: RW, CONST1, RSV0 |
| Register reset | 0x00000003 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Logger enable and mandatory overwrite-oldest policy. OVERWRITE_OLDEST reads one and cannot be cleared. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `LOGGER_ENABLE` | RW | 1 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 1 | `OVERWRITE_OLDEST` | CONST1 | 1 | 1 only | Host writes one; zero rejects the entire mixed-register write | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 23:2 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 31:24 | `RSV0_HI` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_STATUS (`0x0304`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0304` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Event-store state and sticky evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `NOT_EMPTY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 1 | `FULL` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 2 | `SNAPSHOT_VALID` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 3 | `OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 4 | `SOURCE_DROP` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 5 | `POP_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 6 | `CLEAR_COMPLETE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 31:7 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_COUNT (`0x0308`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0308` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Number of retained records. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 6:0 | `COUNT` | RO | 0x00 | 0-64 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 31:7 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_OVERFLOW_COUNT (`0x030C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-030C` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Saturating event-store overwrite count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_SOURCE_ENABLE (`0x0310`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0310` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00FFFFFF |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Per-source event acceptance mask for RTL-001 through RTL-024. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 23:0 | `SOURCE_ENABLE` | RW | 0xFFFFFF | Any defined 24-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 31:24 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_SNAPSHOT (`0x0314`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0314` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Snapshots the oldest retained record. |
| Register-level side effect | Captures without removing the record. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `CAPTURE_OLDEST` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Captures without removing the record. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_DATA0 (`0x0318`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0318` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Snapshot event word 0: timestamp bits 31:0. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMESTAMP_LO` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_DATA1 (`0x031C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-031C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Snapshot event word 1: timestamp bits 63:32. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMESTAMP_HI` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_DATA2 (`0x0320`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0320` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Snapshot event word 2: event ID, source ID, and flags. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `EVENT_ID` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 23:16 | `SOURCE_ID` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 31:24 | `FLAGS` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_DATA3 (`0x0324`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0324` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Snapshot event-specific data. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `EVENT_DATA` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_POP (`0x0328`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0328` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Removes the oldest record after a valid snapshot. |
| Register-level side effect | Removes exactly one record and invalidates snapshot. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `POP` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Removes exactly one record and invalidates snapshot. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_CLEAR (`0x032C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-032C` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | Yes |
| Register behavior | Protected destructive clear of records and overflow evidence. |
| Register-level side effect | Clears logger state only; no unrelated state changes. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `CLEAR_ALL` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Clears logger state only; no unrelated state changes. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_DROP_SOURCE (`0x0330`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0330` |
| Access summary | W1C |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Source bitmap for pending-event overflow. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `SOURCE_DROP` | W1C | 0x00000000 | Any subset of bits 0-23; bits 24-31 zero | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

### EVT_ARB_STATUS (`0x0334`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0334` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-005 |
| Protection | No |
| Register behavior | Event arbiter diagnostics. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 4:0 | `LAST_SOURCE` | RO | 0x00 | 0-0x1F | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 9:5 | `NEXT_SOURCE` | RO | 0x00 | 0-0x1F | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 10 | `ARB_ACTIVE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |
| 31:11 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-005, ARCH-RTL005-001, ARCH-VAL-005 |

## 11. GPIO Controller

Eight-channel direction, output, qualification, observation, and event controls.

| Attribute | Value |
|---|---|
| Address range | 0x0400-0x04FF |
| Primary owner | RTL-006 |
| Register count | 14 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x0400` | `GPIO_CONTROL` | `REG-0400` |
| `0x0404` | `GPIO_DIR` | `REG-0404` |
| `0x0408` | `GPIO_OUT` | `REG-0408` |
| `0x040C` | `GPIO_RAW_IN` | `REG-040C` |
| `0x0410` | `GPIO_SYNC_IN` | `REG-0410` |
| `0x0414` | `GPIO_QUAL_IN` | `REG-0414` |
| `0x0418` | `GPIO_RISE_ENABLE` | `REG-0418` |
| `0x041C` | `GPIO_FALL_ENABLE` | `REG-041C` |
| `0x0420` | `GPIO_EVENT_ENABLE` | `REG-0420` |
| `0x0424` | `GPIO_IRQ_ENABLE` | `REG-0424` |
| `0x0428` | `GPIO_EVENT_STATUS` | `REG-0428` |
| `0x042C` | `GPIO_QUAL_0_3` | `REG-042C` |
| `0x0430` | `GPIO_QUAL_4_7` | `REG-0430` |
| `0x0434` | `RTL006_EVT_OVERFLOW_STATUS` | `REG-0434` |

### GPIO_CONTROL (`0x0400`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0400` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Global GPIO controller enable and qualification control. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 1 | `QUALIFICATION_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:2 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_DIR (`0x0404`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0404` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 / RTL-024 |
| Protection | Yes |
| Register behavior | Direction: zero input/high-Z, one output. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `DIRECTION` | RW | 0x00 | Any defined 8-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### GPIO_OUT (`0x0408`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0408` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Output request values. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `OUTPUT` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_RAW_IN (`0x040C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-040C` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Raw pad input samples after pad wrapper. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `RAW_INPUT` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_SYNC_IN (`0x0410`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0410` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Two-stage synchronized input values. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `SYNC_INPUT` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_QUAL_IN (`0x0414`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0414` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Qualified stable input values. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `QUAL_INPUT` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_RISE_ENABLE (`0x0418`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0418` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Rising-edge condition enable. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `RISE_ENABLE` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_FALL_ENABLE (`0x041C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-041C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Falling-edge condition enable. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `FALL_ENABLE` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_EVENT_ENABLE (`0x0420`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0420` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Per-channel event enable. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `EVENT_ENABLE` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_IRQ_ENABLE (`0x0424`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0424` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Per-channel interrupt enable. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `IRQ_ENABLE` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_EVENT_STATUS (`0x0428`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0428` |
| Access summary | Mixed: W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Sticky per-channel qualified event evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `EVENT` | W1C | 0x00 | 0-0xFF | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_QUAL_0_3 (`0x042C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-042C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Qualification intervals for channels 0-3. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `CH0_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 15:8 | `CH1_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 23:16 | `CH2_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:24 | `CH3_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### GPIO_QUAL_4_7 (`0x0430`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0430` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Qualification intervals for channels 4-7. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `CH4_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 15:8 | `CH5_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 23:16 | `CH6_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:24 | `CH7_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

### RTL006_EVT_OVERFLOW_STATUS (`0x0434`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0434` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-006 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-006, ARCH-RTL006-001, ARCH-VAL-006 |

## 12. Host and Integration Diagnostics

SPI/DRI result evidence, pre-acceptance abort and response-truncation evidence, whole-value diagnostic counters, and shared-buffer status.

| Attribute | Value |
|---|---|
| Address range | 0x0500-0x05FF |
| Primary owner | RTL-024 / RTL-001 |
| Register count | 12 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x0500` | `HOST_CONTROL` | `REG-0500` |
| `0x0504` | `HOST_STATUS` | `REG-0504` |
| `0x0508` | `HOST_LAST_RESULT` | `REG-0508` |
| `0x050C` | `HOST_LAST_ADDRESS` | `REG-050C` |
| `0x0510` | `HOST_COMPLETED_COUNT` | `REG-0510` |
| `0x0514` | `HOST_CRC_ERROR_COUNT` | `REG-0514` |
| `0x0518` | `HOST_ABORT_COUNT` | `REG-0518` |
| `0x051C` | `HOST_TIMEOUT_COUNT` | `REG-051C` |
| `0x0520` | `HOST_ACCESS_ERROR_COUNT` | `REG-0520` |
| `0x0524` | `RTL024_EVT_OVERFLOW_STATUS` | `REG-0524` |
| `0x0528` | `BUFFER_STATUS` | `REG-0528` |
| `0x052C` | `HOST_LAST_SEQUENCE` | `REG-052C` |

### HOST_CONTROL (`0x0500`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0500` |
| Access summary | Mixed: CONST1, RW, RSV0 |
| Register reset | 0x00000001 |
| Owner | RTL-001 / RTL-024 |
| Protection | No |
| Register behavior | Host diagnostic event and interrupt controls. COUNTER_ENABLE is constant one; host diagnostic counters always run. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `COUNTER_ENABLE` | CONST1 | 1 | 1 only | Host writes one; zero rejects the entire mixed-register write | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 1 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 2 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### HOST_STATUS (`0x0504`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0504` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-024 |
| Protection | No |
| Register behavior | Bridge ready/busy and sticky host transaction evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `READY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 1 | `BUSY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 2 | `INVALID_OPCODE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 3 | `INVALID_LENGTH` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 4 | `UNALIGNED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 5 | `INVALID_ADDRESS` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 6 | `ACCESS_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 7 | `PROTECTED_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 8 | `CRC_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 9 | `TIMEOUT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 10 | `ENDPOINT_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 11 | `ABORTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 12 | `RSV0` | RSV0 | 0 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 13 | `RESPONSE_TRUNCATED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:14 | `RSV1` | RSV0 | 0x00000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### HOST_LAST_RESULT (`0x0508`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0508` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-024 |
| Protection | No |
| Register behavior | Terminal result of the most recent accepted command. Pre-acceptance aborts do not change this register; response truncation does not replace the accepted command's terminal result. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `SPI_STATUS` | RO | 0x00 | 0x00 success through 0x0A endpoint error; 0x0B-0xFF reserved | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 10:8 | `DRI_CODE` | RO | 0x0 | 0-6 defined; 7 reserved | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 15:11 | `COMPLETED_COUNT` | RO | 0x00 | 0-16 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 23:16 | `OPCODE` | RO | 0x00 | 0x01 READ or 0x02 WRITE | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:24 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### HOST_LAST_ADDRESS (`0x050C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-050C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-024 |
| Protection | No |
| Register behavior | Starting byte offset of the most recent accepted command. Pre-acceptance aborts do not change this register. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `ADDRESS` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### HOST_COMPLETED_COUNT (`0x0510`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0510` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-024 |
| Protection | No |
| Register behavior | Saturating successful transaction count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### HOST_CRC_ERROR_COUNT (`0x0514`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0514` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-024 |
| Protection | No |
| Register behavior | Saturating command CRC-error count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### HOST_ABORT_COUNT (`0x0518`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0518` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-024 |
| Protection | No |
| Register behavior | Saturating count of pre-acceptance aborts plus post-acceptance response truncations. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### HOST_TIMEOUT_COUNT (`0x051C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-051C` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-024 |
| Protection | No |
| Register behavior | Saturating internal-timeout count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### HOST_ACCESS_ERROR_COUNT (`0x0520`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0520` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-024 |
| Protection | No |
| Register behavior | Saturating invalid/protected/access-error count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### RTL024_EVT_OVERFLOW_STATUS (`0x0524`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0524` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-024 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### BUFFER_STATUS (`0x0528`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0528` |
| Access summary | Mixed: W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-024 |
| Protection | No |
| Register behavior | Sticky per-client and internal centralized shared-buffer error evidence. |
| Register-level side effect | Bitwise W1C; new error evidence dominates clear. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 6:0 | `CLIENT_ERROR` | W1C | 0x00 | 0-0x7F | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 7 | `INTERNAL_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### HOST_LAST_SEQUENCE (`0x052C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-052C` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-024 / RTL-001 |
| Protection | No |
| Register behavior | Eleven-bit sequence number of the most recent accepted command; increments modulo 2048. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 10:0 | `SEQUENCE` | RO | 0x000 | 0-0x7FF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:11 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

## 13. Production Test

Bounded, physically authorized production-test commands, diagnostic loopback selection, and distinguishable injection controls. No register in this block can activate a safety output.

| Attribute | Value |
|---|---|
| Address range | 0x0600-0x06FF |
| Primary owner | RTL-024 / ASIC integration wrapper |
| Register count | 6 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x0600` | `TEST_CONTROL` | `REG-0600` |
| `0x0604` | `TEST_STATUS` | `REG-0604` |
| `0x0608` | `TEST_COMMAND` | `REG-0608` |
| `0x060C` | `TEST_LOOPBACK` | `REG-060C` |
| `0x0610` | `TEST_IRQ_INJECT` | `REG-0610` |
| `0x0614` | `TEST_FAULT_INJECT` | `REG-0614` |

### TEST_CONTROL (`0x0600`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0600` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-024 / ASIC wrapper |
| Protection | Yes |
| Register behavior | Protected bounded production-test enable and policy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 1 | `LOOPBACK_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 2 | `INJECTION_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### TEST_STATUS (`0x0604`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0604` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-024 / ASIC wrapper |
| Protection | No |
| Register behavior | Physical authorization, active state, and sticky test evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `PHYSICAL_AUTH` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 1 | `ACTIVE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 2 | `COMMAND_COMPLETE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 3 | `COMMAND_REJECTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 4 | `SAFETY_BLOCKED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### TEST_COMMAND (`0x0608`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0608` |
| Access summary | WO-CMD |
| Register reset | 0x00000000 |
| Owner | RTL-024 / ASIC wrapper |
| Protection | Yes |
| Register behavior | Bounded production-test command. |
| Register-level side effect | Executes only when TEST_STATUS.ACTIVE is one. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `COMMAND` | WO-CMD | 0x00 | 0x01 CAPTURE; 0x02 SHIFT; 0x03 SAFE_LOOPBACK | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Executes only when TEST_STATUS.ACTIVE is one. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:8 | `ARGUMENT` | WO-CMD | 0x000000 | Command-dependent encoding in REG-ENC-016 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Executes only when TEST_STATUS.ACTIVE is one. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### TEST_LOOPBACK (`0x060C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-060C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-024 |
| Protection | Yes |
| Register behavior | Safe digital loopback selection. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `LOOPBACK_SELECT` | RW | 0x00 | 0-7 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### TEST_IRQ_INJECT (`0x0610`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0610` |
| Access summary | WO-CMD |
| Register reset | 0x00000000 |
| Owner | RTL-024 / RTL-003 |
| Protection | Yes |
| Register behavior | Injects selected internal interrupt source as distinguishable test evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `SOURCE_MASK` | WO-CMD | 0x00000000 | Any subset of bits 0-23; bits 24-31 zero | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one SOURCE_MASK command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-003, ARCH-RTL003-001, ARCH-VAL-003, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### TEST_FAULT_INJECT (`0x0614`)

| Property | Definition |
|---|---|
| Contract ID | `REG-0614` |
| Access summary | WO-CMD |
| Register reset | 0x00000000 |
| Owner | RTL-024 / RTL-013 |
| Protection | Yes |
| Register behavior | Injects selected fault source through the normal fault path. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `SOURCE_MASK` | WO-CMD | 0x00000000 | Any subset of bits 0-16; bits 17-31 zero | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one SOURCE_MASK command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

## 14. ARINC 429 Receive

Eight-entry receive-queue control, coherent snapshot, explicit pop, timestamps, metadata, and error evidence.

| Attribute | Value |
|---|---|
| Address range | 0x1000-0x10FF |
| Primary owner | RTL-017 / RTL-024 receive adapter |
| Register count | 12 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x1000` | `ARX_CONTROL` | `REG-1000` |
| `0x1004` | `ARX_STATUS` | `REG-1004` |
| `0x1008` | `ARX_QUEUE_LEVEL` | `REG-1008` |
| `0x100C` | `ARX_SNAPSHOT` | `REG-100C` |
| `0x1010` | `ARX_DATA` | `REG-1010` |
| `0x1014` | `ARX_META` | `REG-1014` |
| `0x1018` | `ARX_TIME_LO` | `REG-1018` |
| `0x101C` | `ARX_TIME_HI` | `REG-101C` |
| `0x1020` | `ARX_POP` | `REG-1020` |
| `0x1024` | `ARX_ERROR_COUNT` | `REG-1024` |
| `0x1028` | `ARX_OVERFLOW_COUNT` | `REG-1028` |
| `0x102C` | `RTL017_EVT_OVERFLOW_STATUS` | `REG-102C` |

### ARX_CONTROL (`0x1000`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1000` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-017 / RTL-024 |
| Protection | Yes for speed while enabled |
| Register behavior | Receive channel enable, speed, event, and interrupt controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 1 | `HIGH_SPEED` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 2 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 3 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 4 | `ACCEPT_PARITY_ERROR` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### ARX_STATUS (`0x1004`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1004` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Receive state and sticky errors. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLED` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 1 | `NOT_EMPTY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 2 | `FULL` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 3 | `SNAPSHOT_VALID` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 4 | `PARITY_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 5 | `FRAMING_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 6 | `OVERRUN` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 7 | `ADAPTER_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

### ARX_QUEUE_LEVEL (`0x1008`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1008` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Receive queue occupancy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `LEVEL` | RO | 0x0 | 0-8 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

### ARX_SNAPSHOT (`0x100C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-100C` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Snapshots the oldest queued receive word. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `CAPTURE` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one CAPTURE command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

### ARX_DATA (`0x1010`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1010` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Snapshot 32-bit ARINC word. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `WORD` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

### ARX_META (`0x1014`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1014` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Snapshot receive metadata. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `PARITY_OK` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 1 | `FRAMING_OK` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 2 | `HIGH_SPEED` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 3 | `ERROR_PRESENT` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 15:4 | `ERROR_CODE` | RO | 0x000 | 0x000-0x008; 0x009-0xFFF reserved | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 31:16 | `SEQUENCE` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

### ARX_TIME_LO (`0x1018`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1018` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Snapshot timestamp bits 31:0. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMESTAMP_LO` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

### ARX_TIME_HI (`0x101C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-101C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Snapshot timestamp bits 63:32. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMESTAMP_HI` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

### ARX_POP (`0x1020`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1020` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Removes the snapped oldest word. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `POP` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one POP command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

### ARX_ERROR_COUNT (`0x1024`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1024` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Saturating receive error count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

### ARX_OVERFLOW_COUNT (`0x1028`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1028` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Saturating queue overrun count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

### RTL017_EVT_OVERFLOW_STATUS (`0x102C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-102C` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-017 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-017, ARCH-RTL017-001, ARCH-VAL-017 |

## 15. ARINC 429 Transmit

Eight-entry transmit-queue staging, push, parity, speed, interword-gap, and error controls.

| Attribute | Value |
|---|---|
| Address range | 0x1100-0x11FF |
| Primary owner | RTL-018 |
| Register count | 10 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x1100` | `ATX_CONTROL` | `REG-1100` |
| `0x1104` | `ATX_STATUS` | `REG-1104` |
| `0x1108` | `ATX_QUEUE_LEVEL` | `REG-1108` |
| `0x110C` | `ATX_DATA_STAGE` | `REG-110C` |
| `0x1110` | `ATX_META_STAGE` | `REG-1110` |
| `0x1114` | `ATX_PUSH` | `REG-1114` |
| `0x1118` | `ATX_ERROR_COUNT` | `REG-1118` |
| `0x111C` | `ATX_UNDERRUN_COUNT` | `REG-111C` |
| `0x1120` | `RTL018_EVT_OVERFLOW_STATUS` | `REG-1120` |
| `0x1124` | `ATX_INTERWORD_GAP_BITS` | `REG-1124` |

### ATX_CONTROL (`0x1100`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1100` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000010 |
| Owner | RTL-018 |
| Protection | Yes for speed while enabled |
| Register behavior | Transmit channel enable, speed, event, and interrupt controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 1 | `HIGH_SPEED` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 2 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 3 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 4 | `AUTO_PARITY` | RW | 1 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |

### ATX_STATUS (`0x1104`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1104` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000004 |
| Owner | RTL-018 |
| Protection | No |
| Register behavior | Transmit state and sticky errors. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLED` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 1 | `BUSY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 2 | `QUEUE_EMPTY` | RO | 1 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 3 | `QUEUE_FULL` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 4 | `COMPLETE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 5 | `UNDERRUN` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 6 | `REJECTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 7 | `ADAPTER_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |

### ATX_QUEUE_LEVEL (`0x1108`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1108` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-018 |
| Protection | No |
| Register behavior | Transmit queue occupancy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `LEVEL` | RO | 0x0 | 0-8 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |

### ATX_DATA_STAGE (`0x110C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-110C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-018 |
| Protection | No |
| Register behavior | Staged 32-bit transmit word. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `WORD` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |

### ATX_META_STAGE (`0x1110`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1110` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-018 |
| Protection | No |
| Register behavior | Staged transmit metadata. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `PARITY_OVERRIDE_VALID` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 1 | `PARITY_BIT` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 15:2 | `TAG` | RW | 0x0000 | 0-0x3FFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |

### ATX_PUSH (`0x1114`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1114` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-018 |
| Protection | No |
| Register behavior | Commits one staged transmit request to the queue. |
| Register-level side effect | Queue-full or disabled request is rejected without changing queue. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `PUSH` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Queue-full or disabled request is rejected without changing queue. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |

### ATX_ERROR_COUNT (`0x1118`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1118` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-018 |
| Protection | No |
| Register behavior | Saturating transmit error/rejection count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |

### ATX_UNDERRUN_COUNT (`0x111C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-111C` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-018 |
| Protection | No |
| Register behavior | Saturating underrun count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |

### RTL018_EVT_OVERFLOW_STATUS (`0x1120`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1120` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-018 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |

### ATX_INTERWORD_GAP_BITS (`0x1124`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1124` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000004 |
| Owner | RTL-018 |
| Protection | Yes while enabled |
| Register behavior | ARINC transmit null interval in bit times. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `GAP_BITS` | RW | 0x04 | 4-255 bit times | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-018, ARCH-RTL018-001, ARCH-VAL-018 |

## 16. Classical CAN

Classical CAN 2.0A/2.0B configuration, receive snapshot/pop, transmit stage/push, error confinement, and bus-off recovery.

| Attribute | Value |
|---|---|
| Address range | 0x1200-0x12FF |
| Primary owner | RTL-019 |
| Register count | 21 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x1200` | `CAN_CONTROL` | `REG-1200` |
| `0x1204` | `CAN_STATUS` | `REG-1204` |
| `0x1208` | `CAN_BIT_TIMING` | `REG-1208` |
| `0x120C` | `CAN_ERROR_COUNT` | `REG-120C` |
| `0x1210` | `CAN_RX_LEVEL` | `REG-1210` |
| `0x1214` | `CAN_RX_SNAPSHOT` | `REG-1214` |
| `0x1218` | `CAN_RX_ID` | `REG-1218` |
| `0x121C` | `CAN_RX_META` | `REG-121C` |
| `0x1220` | `CAN_RX_DATA_LO` | `REG-1220` |
| `0x1224` | `CAN_RX_DATA_HI` | `REG-1224` |
| `0x1228` | `CAN_RX_TIME_LO` | `REG-1228` |
| `0x122C` | `CAN_RX_TIME_HI` | `REG-122C` |
| `0x1230` | `CAN_RX_POP` | `REG-1230` |
| `0x1234` | `CAN_TX_LEVEL` | `REG-1234` |
| `0x1238` | `CAN_TX_ID_STAGE` | `REG-1238` |
| `0x123C` | `CAN_TX_META_STAGE` | `REG-123C` |
| `0x1240` | `CAN_TX_DATA_LO_STAGE` | `REG-1240` |
| `0x1244` | `CAN_TX_DATA_HI_STAGE` | `REG-1244` |
| `0x1248` | `CAN_TX_PUSH` | `REG-1248` |
| `0x124C` | `RTL019_EVT_OVERFLOW_STATUS` | `REG-124C` |
| `0x1250` | `CAN_RECOVERY` | `REG-1250` |

### CAN_CONTROL (`0x1200`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1200` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | Yes for mode changes |
| Register behavior | Controller enable, test modes, events, and interrupts. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 1 | `LOOPBACK` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 2 | `LISTEN_ONLY` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 3 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 4 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 5 | `AUTOMATIC_BUS_OFF_RECOVERY` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:6 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_STATUS (`0x1204`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1204` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000004 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | CAN operational and sticky error status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLED` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 1 | `RX_NOT_EMPTY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 2 | `TX_NOT_FULL` | RO | 1 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 3 | `ERROR_WARNING` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 4 | `ERROR_PASSIVE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 5 | `BUS_OFF` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 6 | `RX_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 7 | `TX_REJECTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 8 | `PROTOCOL_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 9 | `TRANSCEIVER_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:10 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_BIT_TIMING (`0x1208`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1208` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | Yes |
| Register behavior | Staged/active bit-timing parameters; changes only while disabled. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 9:0 | `PRESCALER_MINUS_1` | RW | 0x000 | Per REG-ENC-006 and the cross-field timing equation | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 15:10 | `TSEG1_MINUS_1` | RW | 0x00 | Per REG-ENC-006 and the cross-field timing equation | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 20:16 | `TSEG2_MINUS_1` | RW | 0x00 | Per REG-ENC-006 and the cross-field timing equation | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 24:21 | `SJW_MINUS_1` | RW | 0x0 | Per REG-ENC-006 and the cross-field timing equation | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:25 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_ERROR_COUNT (`0x120C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-120C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | CAN protocol error counters. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `TX_ERROR_COUNT` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 15:8 | `RX_ERROR_COUNT` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:16 | `PROTOCOL_ERROR_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_RX_LEVEL (`0x1210`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1210` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | RX queue occupancy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `LEVEL` | RO | 0x0 | 0-8 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_RX_SNAPSHOT (`0x1214`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1214` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | Snapshots oldest RX frame. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `CAPTURE` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one CAPTURE command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_RX_ID (`0x1218`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1218` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | Snapshot identifier. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 28:0 | `IDENTIFIER` | RO | 0x00000000 | 11-bit standard or 29-bit extended identifier; standard bits 28:11 zero | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 29 | `IDE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 30 | `RTR` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_RX_META (`0x121C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-121C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | Snapshot frame metadata. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `DLC` | RO | 0x0 | 0-8 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 15:4 | `FLAGS` | RO | 0x000 | Bits 0-9 defined; bits 10-11 zero | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:16 | `SEQUENCE` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_RX_DATA_LO (`0x1220`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1220` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | Snapshot payload bytes 0-3. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `DATA_0_3` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_RX_DATA_HI (`0x1224`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1224` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | Snapshot payload bytes 4-7. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `DATA_4_7` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_RX_TIME_LO (`0x1228`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1228` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | Snapshot timestamp bits 31:0. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMESTAMP_LO` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_RX_TIME_HI (`0x122C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-122C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | Snapshot timestamp bits 63:32. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMESTAMP_HI` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_RX_POP (`0x1230`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1230` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | Removes snapped RX frame. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `POP` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one POP command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_TX_LEVEL (`0x1234`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1234` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | TX queue occupancy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `LEVEL` | RO | 0x0 | 0-8 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_TX_ID_STAGE (`0x1238`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1238` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-019 |
| Protection | No |
| Register behavior | Staged transmit identifier and format. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 28:0 | `IDENTIFIER` | RW | 0x00000000 | 11-bit standard or 29-bit extended identifier; standard bits 28:11 zero | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 29 | `IDE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 30 | `RTR` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31 | `RSV0` | RSV0 | 0 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_TX_META_STAGE (`0x123C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-123C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-019 |
| Protection | No |
| Register behavior | Staged transmit metadata. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `DLC` | RW | 0x0 | 0-8; 9-15 reserved | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_TX_DATA_LO_STAGE (`0x1240`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1240` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-019 |
| Protection | No |
| Register behavior | Staged payload bytes 0-3. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `DATA_0_3` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_TX_DATA_HI_STAGE (`0x1244`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1244` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-019 |
| Protection | No |
| Register behavior | Staged payload bytes 4-7. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `DATA_4_7` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_TX_PUSH (`0x1248`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1248` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | Validates and pushes one staged transmit frame. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `PUSH` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one PUSH command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### RTL019_EVT_OVERFLOW_STATUS (`0x124C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-124C` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

### CAN_RECOVERY (`0x1250`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1250` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-019 |
| Protection | Yes |
| Register behavior | Requests manual bus-off recovery after the Architecture-defined recessive-bus observation requirement is satisfied. |
| Register-level side effect | One bounded recovery request; reads zero. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `REQUEST` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | One bounded recovery request; reads zero. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-019, ARCH-RTL019-001, ARCH-VAL-019 |

## 17. UART

Eight-data-bit UART framing, baud divisor, 16-byte receive/transmit queues, explicit pop/push, and persistent error evidence.

| Attribute | Value |
|---|---|
| Address range | 0x1300-0x13FF |
| Primary owner | RTL-020 |
| Register count | 11 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x1300` | `UART_CONTROL` | `REG-1300` |
| `0x1304` | `UART_STATUS` | `REG-1304` |
| `0x1308` | `UART_BAUD_DIV` | `REG-1308` |
| `0x130C` | `UART_RX_LEVEL` | `REG-130C` |
| `0x1310` | `UART_RX_DATA` | `REG-1310` |
| `0x1314` | `UART_RX_POP` | `REG-1314` |
| `0x1318` | `UART_TX_LEVEL` | `REG-1318` |
| `0x131C` | `UART_TX_DATA` | `REG-131C` |
| `0x1320` | `UART_TX_PUSH` | `REG-1320` |
| `0x1324` | `UART_ERROR_COUNT` | `REG-1324` |
| `0x1328` | `RTL020_EVT_OVERFLOW_STATUS` | `REG-1328` |

### UART_CONTROL (`0x1300`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1300` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-020 |
| Protection | Yes for format while enabled |
| Register behavior | UART enable and frame format. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 2:1 | `PARITY` | RW | 0x0 | 0 none; 1 even; 2 odd; 3 reserved | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 3 | `TWO_STOP_BITS` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 4 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 5 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 31:6 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

### UART_STATUS (`0x1304`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1304` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000004 |
| Owner | RTL-020 |
| Protection | No |
| Register behavior | UART state and sticky errors. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLED` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 1 | `RX_NOT_EMPTY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 2 | `TX_NOT_FULL` | RO | 1 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 3 | `TX_BUSY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 4 | `FRAMING_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 5 | `PARITY_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 6 | `RX_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 7 | `TX_UNDERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 8 | `BREAK_DETECTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 31:9 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

### UART_BAUD_DIV (`0x1308`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1308` |
| Access summary | RW |
| Register reset | 0x000001B2 |
| Owner | RTL-020 |
| Protection | Yes |
| Register behavior | Core-clock divisor for configured baud rate; changes only while disabled. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `DIVISOR` | RW | 0x000001B2 | 50-50,000; reset 434 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

### UART_RX_LEVEL (`0x130C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-130C` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-020 |
| Protection | No |
| Register behavior | Receive queue level. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 4:0 | `LEVEL` | RO | 0x00 | 0-16 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

### UART_RX_DATA (`0x1310`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1310` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-020 |
| Protection | No |
| Register behavior | Oldest receive byte and metadata snapshot. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `DATA` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 15:8 | `ERROR_FLAGS` | RO | 0x00 | Bits 0-4 defined; bits 5-7 zero | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 16 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 31:17 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

### UART_RX_POP (`0x1314`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1314` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-020 |
| Protection | No |
| Register behavior | Removes the oldest receive byte. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `POP` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one POP command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

### UART_TX_LEVEL (`0x1318`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1318` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-020 |
| Protection | No |
| Register behavior | Transmit queue level. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 4:0 | `LEVEL` | RO | 0x00 | 0-16 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

### UART_TX_DATA (`0x131C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-131C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-020 |
| Protection | No |
| Register behavior | Staged transmit byte. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `DATA` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

### UART_TX_PUSH (`0x1320`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1320` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-020 |
| Protection | No |
| Register behavior | Pushes one staged transmit byte. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `PUSH` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one PUSH command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

### UART_ERROR_COUNT (`0x1324`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1324` |
| Access summary | COUNTER-CLR |
| Register reset | 0x00000000 |
| Owner | RTL-020 |
| Protection | No |
| Register behavior | Saturating aggregate UART error count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `COUNT` | COUNTER-CLR | 0x00000000 | Read 0x00000000-0xFFFFFFFF; writes only 0x00000000 or 0xFFFFFFFF | 0 has no effect; 0xFFFFFFFF emits one clear pulse; every other word is ACCESS_ERROR | Reads current retained value | Clears the whole counter only on the all-ones command | Reset, then increment/saturation, then clear | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

### RTL020_EVT_OVERFLOW_STATUS (`0x1328`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1328` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-020 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-020, ARCH-RTL020-001, ARCH-VAL-020 |

## 18. Databus Routing Engine

Sixteen staged route entries with atomic validation/commit, exact five-source/five-destination encodings, filtering, replication, and drop evidence.

| Attribute | Value |
|---|---|
| Address range | 0x1400-0x14FF |
| Primary owner | RTL-021 |
| Register count | 17 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x1400` | `ROUTE_CONTROL` | `REG-1400` |
| `0x1404` | `ROUTE_STATUS` | `REG-1404` |
| `0x1408` | `ROUTE_ENTRY_SELECT` | `REG-1408` |
| `0x140C` | `ROUTE_STAGE_SOURCE` | `REG-140C` |
| `0x1410` | `ROUTE_STAGE_DEST` | `REG-1410` |
| `0x1414` | `ROUTE_STAGE_TYPE_MASK` | `REG-1414` |
| `0x1418` | `ROUTE_STAGE_FILTER_VALUE` | `REG-1418` |
| `0x141C` | `ROUTE_STAGE_FILTER_MASK` | `REG-141C` |
| `0x1420` | `ROUTE_STAGE_CONTROL` | `REG-1420` |
| `0x1424` | `ROUTE_VALIDATE_COMMIT` | `REG-1424` |
| `0x1428` | `ROUTE_ACTIVE_SOURCE` | `REG-1428` |
| `0x142C` | `ROUTE_ACTIVE_DEST` | `REG-142C` |
| `0x1430` | `ROUTE_ACTIVE_TYPE_MASK` | `REG-1430` |
| `0x1434` | `ROUTE_ACTIVE_FILTER_VALUE` | `REG-1434` |
| `0x1438` | `ROUTE_ACTIVE_FILTER_MASK` | `REG-1438` |
| `0x143C` | `ROUTE_ENTRY_STATUS` | `REG-143C` |
| `0x1440` | `RTL021_EVT_OVERFLOW_STATUS` | `REG-1440` |

### ROUTE_CONTROL (`0x1400`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1400` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-021 |
| Protection | Yes |
| Register behavior | Global routing enable and diagnostics controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 1 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 2 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_STATUS (`0x1404`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1404` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-021 |
| Protection | No |
| Register behavior | Routing activity and sticky commit/runtime errors. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ACTIVE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 1 | `COMMIT_COMPLETE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 2 | `COMMIT_REJECTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 3 | `DEST_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 4 | `UNAUTHORIZED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 7:5 | `RSV0` | RSV0 | 0x0 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 15:8 | `LAST_ERROR` | RO | 0x00 | 0x00, 0x01-0x08 commit results, or 0x10-0x15 runtime results; all others reserved | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:16 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_ENTRY_SELECT (`0x1408`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1408` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-021 |
| Protection | No |
| Register behavior | Selects route entry 0-15 for staging/readback. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `ENTRY` | RW | 0x0 | 0-15 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_STAGE_SOURCE (`0x140C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-140C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-021 |
| Protection | No |
| Register behavior | Staged source identifier. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `SOURCE_ID` | RW | 0x00 | 0-4 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_STAGE_DEST (`0x1410`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1410` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-021 |
| Protection | No |
| Register behavior | Staged destination mask. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 4:0 | `DEST_MASK` | RW | 0x00 | 0x01-0x1F when enabled; fixed source/destination matrix applies | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_STAGE_TYPE_MASK (`0x1414`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1414` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-021 |
| Protection | No |
| Register behavior | Staged permitted canonical message-type mask. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TYPE_MASK` | RW | 0x00000000 | Only bits 0-4; nonzero when enabled | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_STAGE_FILTER_VALUE (`0x1418`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1418` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-021 |
| Protection | No |
| Register behavior | Staged metadata filter comparison value. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `FILTER_VALUE` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_STAGE_FILTER_MASK (`0x141C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-141C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-021 |
| Protection | No |
| Register behavior | Staged metadata filter mask; zero disables filtering. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `FILTER_MASK` | RW | 0x00000000 | Any defined 32-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_STAGE_CONTROL (`0x1420`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1420` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-021 |
| Protection | No |
| Register behavior | Staged route enable and replication policy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 1 | `DROP_ON_FULL` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:2 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_VALIDATE_COMMIT (`0x1424`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1424` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-021 |
| Protection | Yes |
| Register behavior | Validates and atomically commits selected staged entry. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `VALIDATE_COMMIT` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one VALIDATE_COMMIT command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 1 | `DISABLE_ENTRY` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one DISABLE_ENTRY command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:2 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_ACTIVE_SOURCE (`0x1428`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1428` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-021 |
| Protection | No |
| Register behavior | Active selected entry source. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `SOURCE` | RO | 0x00 | 0-4 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_ACTIVE_DEST (`0x142C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-142C` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-021 |
| Protection | No |
| Register behavior | Active selected entry destination mask. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 4:0 | `DEST_MASK` | RO | 0x00 | 0x00-0x1F | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_ACTIVE_TYPE_MASK (`0x1430`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1430` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-021 |
| Protection | No |
| Register behavior | Active selected entry message-type mask. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TYPE_MASK` | RO | 0x00000000 | Any defined 32-bit subset; reserved source bits zero | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_ACTIVE_FILTER_VALUE (`0x1434`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1434` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-021 |
| Protection | No |
| Register behavior | Active selected entry filter value. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `FILTER_VALUE` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_ACTIVE_FILTER_MASK (`0x1438`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1438` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-021 |
| Protection | No |
| Register behavior | Active selected entry filter mask. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `FILTER_MASK` | RO | 0x00000000 | Any defined 32-bit subset; reserved source bits zero | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### ROUTE_ENTRY_STATUS (`0x143C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-143C` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-021 |
| Protection | No |
| Register behavior | Selected entry status and counters. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ACTIVE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 1 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 2 | `ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 15:3 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:16 | `FORWARDED_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

### RTL021_EVT_OVERFLOW_STATUS (`0x1440`)

| Property | Definition |
|---|---|
| Contract ID | `REG-1440` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-021 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-021, ARCH-RTL021-001, ARCH-VAL-021 |

## 19. Rotor RPM Monitor

Rotor measurement, threshold, hysteresis, timeout, qualification, event, and interrupt controls.

| Attribute | Value |
|---|---|
| Address range | 0x2000-0x20FF |
| Primary owner | RTL-007 |
| Register count | 11 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x2000` | `ROTOR_CONTROL` | `REG-2000` |
| `0x2004` | `ROTOR_STATUS` | `REG-2004` |
| `0x2008` | `ROTOR_RPM` | `REG-2008` |
| `0x200C` | `ROTOR_PERIOD_TICKS` | `REG-200C` |
| `0x2010` | `ROTOR_THRESH_LOW` | `REG-2010` |
| `0x2014` | `ROTOR_THRESH_HIGH` | `REG-2014` |
| `0x2018` | `ROTOR_PULSES_PER_REV` | `REG-2018` |
| `0x201C` | `ROTOR_TIMEOUT_US` | `REG-201C` |
| `0x2020` | `ROTOR_EDGE_FILTER` | `REG-2020` |
| `0x2024` | `RTL007_EVT_OVERFLOW_STATUS` | `REG-2024` |
| `0x2028` | `ROTOR_HYSTERESIS` | `REG-2028` |

### ROTOR_CONTROL (`0x2000`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2000` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000002 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | Rotor monitor enable, edge, event, and interrupt controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 1 | `RISING_EDGE` | RW | 1 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 2 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 3 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

### ROTOR_STATUS (`0x2004`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2004` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | Measurement validity and sticky threshold/error status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 1 | `LOW` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 2 | `HIGH` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 3 | `TIMEOUT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 4 | `RANGE_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 5 | `UPDATED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 31:6 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

### ROTOR_RPM (`0x2008`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2008` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | Current RPM in whole revolutions per minute. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `RPM` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

### ROTOR_PERIOD_TICKS (`0x200C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-200C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | Measured edge period in 50 MHz core-clock ticks. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PERIOD_TICKS` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

### ROTOR_THRESH_LOW (`0x2010`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2010` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | Low RPM threshold. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `THRESHOLD` | RW | 0x0000 | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

### ROTOR_THRESH_HIGH (`0x2014`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2014` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x000003E8 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | High RPM threshold. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `THRESHOLD` | RW | 0x03E8 | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

### ROTOR_PULSES_PER_REV (`0x2018`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2018` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000001 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | Pulses per revolution. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `PPR` | RW | 0x0001 | 1-65,535 when enabled | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

### ROTOR_TIMEOUT_US (`0x201C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-201C` |
| Access summary | RW |
| Register reset | 0x000186A0 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | No-edge timeout in microseconds. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMEOUT_US` | RW | 0x000186A0 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

### ROTOR_EDGE_FILTER (`0x2020`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2020` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | Minimum accepted edge separation in core-clock cycles. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MIN_EDGE_CYCLES` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

### RTL007_EVT_OVERFLOW_STATUS (`0x2024`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2024` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

### ROTOR_HYSTERESIS (`0x2028`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2028` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-007 |
| Protection | No |
| Register behavior | Symmetric RPM threshold hysteresis. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `HYSTERESIS` | RW | 0x0000 | 0 through HIGH-LOW under the applicable signed/unsigned comparison | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-007, ARCH-RTL007-001, ARCH-VAL-007 |

## 20. Engine RPM Monitor

Engine measurement, threshold, hysteresis, timeout, qualification, event, and interrupt controls.

| Attribute | Value |
|---|---|
| Address range | 0x2100-0x21FF |
| Primary owner | RTL-008 |
| Register count | 11 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x2100` | `ENGINE_CONTROL` | `REG-2100` |
| `0x2104` | `ENGINE_STATUS` | `REG-2104` |
| `0x2108` | `ENGINE_RPM` | `REG-2108` |
| `0x210C` | `ENGINE_PERIOD_TICKS` | `REG-210C` |
| `0x2110` | `ENGINE_THRESH_LOW` | `REG-2110` |
| `0x2114` | `ENGINE_THRESH_HIGH` | `REG-2114` |
| `0x2118` | `ENGINE_PULSES_PER_REV` | `REG-2118` |
| `0x211C` | `ENGINE_TIMEOUT_US` | `REG-211C` |
| `0x2120` | `ENGINE_EDGE_FILTER` | `REG-2120` |
| `0x2124` | `RTL008_EVT_OVERFLOW_STATUS` | `REG-2124` |
| `0x2128` | `ENGINE_HYSTERESIS` | `REG-2128` |

### ENGINE_CONTROL (`0x2100`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2100` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000002 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | Engine monitor enable, edge, event, and interrupt controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 1 | `RISING_EDGE` | RW | 1 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 2 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 3 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

### ENGINE_STATUS (`0x2104`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2104` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | Measurement validity and sticky threshold/error status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 1 | `LOW` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 2 | `HIGH` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 3 | `TIMEOUT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 4 | `RANGE_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 5 | `UPDATED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 31:6 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

### ENGINE_RPM (`0x2108`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2108` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | Current RPM in whole revolutions per minute. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `RPM` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

### ENGINE_PERIOD_TICKS (`0x210C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-210C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | Measured edge period in 50 MHz core-clock ticks. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PERIOD_TICKS` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

### ENGINE_THRESH_LOW (`0x2110`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2110` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | Low RPM threshold. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `THRESHOLD` | RW | 0x0000 | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

### ENGINE_THRESH_HIGH (`0x2114`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2114` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00004E20 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | High RPM threshold. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `THRESHOLD` | RW | 0x4E20 | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

### ENGINE_PULSES_PER_REV (`0x2118`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2118` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000001 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | Pulses per revolution. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `PPR` | RW | 0x0001 | 1-65,535 when enabled | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

### ENGINE_TIMEOUT_US (`0x211C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-211C` |
| Access summary | RW |
| Register reset | 0x000186A0 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | No-edge timeout in microseconds. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMEOUT_US` | RW | 0x000186A0 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

### ENGINE_EDGE_FILTER (`0x2120`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2120` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | Minimum accepted edge separation in core-clock cycles. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MIN_EDGE_CYCLES` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

### RTL008_EVT_OVERFLOW_STATUS (`0x2124`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2124` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

### ENGINE_HYSTERESIS (`0x2128`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2128` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-008 |
| Protection | No |
| Register behavior | Symmetric RPM threshold hysteresis. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 15:0 | `HYSTERESIS` | RW | 0x0000 | 0 through HIGH-LOW under the applicable signed/unsigned comparison | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-008, ARCH-RTL008-001, ARCH-VAL-008 |

## 21. Pulse/Frequency Measurement

Two independent Q17.15 frequency channels with threshold, hysteresis, timeout, and qualification controls.

| Attribute | Value |
|---|---|
| Address range | 0x2200-0x22FF |
| Primary owner | RTL-009 |
| Register count | 19 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x2200` | `PULSE0_CONTROL` | `REG-2200` |
| `0x2204` | `PULSE0_STATUS` | `REG-2204` |
| `0x2208` | `PULSE0_FREQ_Q17_15` | `REG-2208` |
| `0x220C` | `PULSE0_PERIOD_TICKS` | `REG-220C` |
| `0x2210` | `PULSE0_THRESH_LOW_Q17_15` | `REG-2210` |
| `0x2214` | `PULSE0_THRESH_HIGH_Q17_15` | `REG-2214` |
| `0x2218` | `PULSE0_TIMEOUT_US` | `REG-2218` |
| `0x221C` | `PULSE0_EDGE_FILTER` | `REG-221C` |
| `0x2220` | `PULSE0_HYSTERESIS_Q17_15` | `REG-2220` |
| `0x2230` | `PULSE1_CONTROL` | `REG-2230` |
| `0x2234` | `PULSE1_STATUS` | `REG-2234` |
| `0x2238` | `PULSE1_FREQ_Q17_15` | `REG-2238` |
| `0x223C` | `PULSE1_PERIOD_TICKS` | `REG-223C` |
| `0x2240` | `PULSE1_THRESH_LOW_Q17_15` | `REG-2240` |
| `0x2244` | `PULSE1_THRESH_HIGH_Q17_15` | `REG-2244` |
| `0x2248` | `PULSE1_TIMEOUT_US` | `REG-2248` |
| `0x224C` | `PULSE1_EDGE_FILTER` | `REG-224C` |
| `0x2250` | `RTL009_EVT_OVERFLOW_STATUS` | `REG-2250` |
| `0x2254` | `PULSE1_HYSTERESIS_Q17_15` | `REG-2254` |

### PULSE0_CONTROL (`0x2200`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2200` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000002 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 0 controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 1 | `RISING_EDGE` | RW | 1 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 2 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 3 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE0_STATUS (`0x2204`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2204` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 0 validity, threshold, timeout, and error status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 1 | `LOW` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 2 | `HIGH` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 3 | `TIMEOUT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 4 | `RANGE_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 5 | `UPDATED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 31:6 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE0_FREQ_Q17_15 (`0x2208`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2208` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 0 frequency in unsigned Q17.15 hertz. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `FREQUENCY_Q17_15` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE0_PERIOD_TICKS (`0x220C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-220C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 0 measured period in core-clock ticks. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PERIOD_TICKS` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE0_THRESH_LOW_Q17_15 (`0x2210`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2210` |
| Access summary | RW |
| Register reset | 0x00004000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 0 low threshold, default 0.5 Hz. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `THRESHOLD` | RW | 0x00004000 | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE0_THRESH_HIGH_Q17_15 (`0x2214`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2214` |
| Access summary | RW |
| Register reset | 0xC3500000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 0 high threshold, saturated representation for supported range. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `THRESHOLD` | RW | 0xC3500000 | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE0_TIMEOUT_US (`0x2218`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2218` |
| Access summary | RW |
| Register reset | 0x002625A0 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 0 no-edge timeout in microseconds. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMEOUT_US` | RW | 0x002625A0 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE0_EDGE_FILTER (`0x221C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-221C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 0 minimum accepted edge separation. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MIN_EDGE_CYCLES` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE0_HYSTERESIS_Q17_15 (`0x2220`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2220` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Channel 0 symmetric threshold hysteresis in unsigned Q17.15 hertz. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `HYSTERESIS` | RW | 0x00000000 | 0 through HIGH-LOW under the applicable signed/unsigned comparison | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE1_CONTROL (`0x2230`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2230` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000002 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 1 controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 1 | `RISING_EDGE` | RW | 1 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 2 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 3 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE1_STATUS (`0x2234`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2234` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 1 validity, threshold, timeout, and error status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 1 | `LOW` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 2 | `HIGH` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 3 | `TIMEOUT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 4 | `RANGE_ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 5 | `UPDATED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 31:6 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE1_FREQ_Q17_15 (`0x2238`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2238` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 1 frequency in unsigned Q17.15 hertz. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `FREQUENCY_Q17_15` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE1_PERIOD_TICKS (`0x223C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-223C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 1 measured period in core-clock ticks. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PERIOD_TICKS` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE1_THRESH_LOW_Q17_15 (`0x2240`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2240` |
| Access summary | RW |
| Register reset | 0x00004000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 1 low threshold, default 0.5 Hz. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `THRESHOLD` | RW | 0x00004000 | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE1_THRESH_HIGH_Q17_15 (`0x2244`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2244` |
| Access summary | RW |
| Register reset | 0xC3500000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 1 high threshold, saturated representation for supported range. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `THRESHOLD` | RW | 0xC3500000 | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE1_TIMEOUT_US (`0x2248`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2248` |
| Access summary | RW |
| Register reset | 0x002625A0 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 1 no-edge timeout in microseconds. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMEOUT_US` | RW | 0x002625A0 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE1_EDGE_FILTER (`0x224C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-224C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Pulse channel 1 minimum accepted edge separation. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MIN_EDGE_CYCLES` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### RTL009_EVT_OVERFLOW_STATUS (`0x2250`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2250` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

### PULSE1_HYSTERESIS_Q17_15 (`0x2254`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2254` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-009 |
| Protection | No |
| Register behavior | Channel 1 symmetric threshold hysteresis in unsigned Q17.15 hertz. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `HYSTERESIS` | RW | 0x00000000 | 0 through HIGH-LOW under the applicable signed/unsigned comparison | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-009, ARCH-RTL009-001, ARCH-VAL-009 |

## 22. Sensor Monitor Interface

Two signed 32-bit sampled-sensor channels with atomic host updates, source/sequence readback, signed thresholds, hysteresis, and stale timing.

| Attribute | Value |
|---|---|
| Address range | 0x2300-0x23FF |
| Primary owner | RTL-010 |
| Register count | 25 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x2300` | `SENSOR_CONTROL` | `REG-2300` |
| `0x2304` | `SENSOR_STATUS` | `REG-2304` |
| `0x2308` | `SENSOR_UPDATE_SELECT` | `REG-2308` |
| `0x230C` | `SENSOR_UPDATE_VALUE` | `REG-230C` |
| `0x2310` | `SENSOR_UPDATE_META` | `REG-2310` |
| `0x2314` | `SENSOR_UPDATE_COMMIT` | `REG-2314` |
| `0x2320` | `SENSOR0_VALUE` | `REG-2320` |
| `0x2324` | `SENSOR0_STATUS` | `REG-2324` |
| `0x2328` | `SENSOR0_MAX_AGE_MS` | `REG-2328` |
| `0x232C` | `SENSOR0_CURRENT_AGE_MS` | `REG-232C` |
| `0x2330` | `SENSOR0_THRESH_LOW` | `REG-2330` |
| `0x2334` | `SENSOR0_THRESH_HIGH` | `REG-2334` |
| `0x2338` | `SENSOR0_EVENT_IRQ_CFG` | `REG-2338` |
| `0x2340` | `SENSOR1_VALUE` | `REG-2340` |
| `0x2344` | `SENSOR1_STATUS` | `REG-2344` |
| `0x2348` | `SENSOR1_MAX_AGE_MS` | `REG-2348` |
| `0x234C` | `SENSOR1_CURRENT_AGE_MS` | `REG-234C` |
| `0x2350` | `SENSOR1_THRESH_LOW` | `REG-2350` |
| `0x2354` | `SENSOR1_THRESH_HIGH` | `REG-2354` |
| `0x2358` | `SENSOR1_EVENT_IRQ_CFG` | `REG-2358` |
| `0x235C` | `RTL010_EVT_OVERFLOW_STATUS` | `REG-235C` |
| `0x2360` | `SENSOR0_HYSTERESIS` | `REG-2360` |
| `0x2364` | `SENSOR0_META` | `REG-2364` |
| `0x2368` | `SENSOR1_HYSTERESIS` | `REG-2368` |
| `0x236C` | `SENSOR1_META` | `REG-236C` |

### SENSOR_CONTROL (`0x2300`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2300` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Global sampled-sensor monitor controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 1 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 2 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR_STATUS (`0x2304`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2304` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Aggregate sensor monitor status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ANY_INVALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 1 | `ANY_STALE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 2 | `ANY_LOW` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 3 | `ANY_HIGH` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 4 | `UPDATE_REJECTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 5 | `UPDATED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31:6 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR_UPDATE_SELECT (`0x2308`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2308` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-010 |
| Protection | No |
| Register behavior | Selects channel for staged update. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `CHANNEL` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR_UPDATE_VALUE (`0x230C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-230C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-010 |
| Protection | No |
| Register behavior | Staged signed 32-bit two's-complement sampled-sensor value. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `VALUE` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR_UPDATE_META (`0x2310`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2310` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-010 |
| Protection | No |
| Register behavior | Staged validity and source metadata. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `VALID` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 7:1 | `SOURCE` | RW | 0x00 | 0-127 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31:8 | `SEQUENCE` | RW | 0x000000 | 0-0xFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR_UPDATE_COMMIT (`0x2314`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2314` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-010 |
| Protection | No |
| Register behavior | Atomically commits the staged sampled value. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `COMMIT` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one COMMIT command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR0_VALUE (`0x2320`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2320` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Current channel 0 value, interpreted as signed 32-bit two's-complement. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `VALUE` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR0_STATUS (`0x2324`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2324` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 0 validity, stale, thresholds, and event evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 1 | `STALE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 2 | `LOW` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 3 | `HIGH` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 4 | `EVENT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR0_MAX_AGE_MS (`0x2328`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2328` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 0 maximum age in milliseconds; zero disables stale checking. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MAX_AGE_MS` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR0_CURRENT_AGE_MS (`0x232C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-232C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 0 saturating current age in milliseconds. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `CURRENT_AGE_MS` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR0_THRESH_LOW (`0x2330`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2330` |
| Access summary | RW |
| Register reset | 0x80000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 0 low threshold, interpreted as signed 32-bit two's-complement. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `THRESHOLD` | RW | 0x80000000 | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR0_THRESH_HIGH (`0x2334`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2334` |
| Access summary | RW |
| Register reset | 0x7FFFFFFF |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 0 high threshold, interpreted as signed 32-bit two's-complement. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `THRESHOLD` | RW | 0x7FFFFFFF | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR0_EVENT_IRQ_CFG (`0x2338`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2338` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 0 abnormal-condition event and interrupt enables. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `EVENT_ENABLE` | RW | 0x0 | 0-15 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 7:4 | `IRQ_ENABLE` | RW | 0x0 | 0-15 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR1_VALUE (`0x2340`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2340` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Current channel 1 value, interpreted as signed 32-bit two's-complement. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `VALUE` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR1_STATUS (`0x2344`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2344` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 1 validity, stale, thresholds, and event evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 1 | `STALE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 2 | `LOW` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 3 | `HIGH` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 4 | `EVENT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR1_MAX_AGE_MS (`0x2348`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2348` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 1 maximum age in milliseconds. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MAX_AGE_MS` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR1_CURRENT_AGE_MS (`0x234C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-234C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 1 saturating current age in milliseconds. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `CURRENT_AGE_MS` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR1_THRESH_LOW (`0x2350`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2350` |
| Access summary | RW |
| Register reset | 0x80000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 1 low threshold, interpreted as signed 32-bit two's-complement. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `THRESHOLD` | RW | 0x80000000 | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR1_THRESH_HIGH (`0x2354`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2354` |
| Access summary | RW |
| Register reset | 0x7FFFFFFF |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 1 high threshold, interpreted as signed 32-bit two's-complement. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `THRESHOLD` | RW | 0x7FFFFFFF | Applicable monitor range; LOW <= HIGH | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR1_EVENT_IRQ_CFG (`0x2358`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2358` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 1 abnormal-condition event and interrupt enables. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `EVENT_ENABLE` | RW | 0x0 | 0-15 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 7:4 | `IRQ_ENABLE` | RW | 0x0 | 0-15 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### RTL010_EVT_OVERFLOW_STATUS (`0x235C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-235C` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR0_HYSTERESIS (`0x2360`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2360` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 0 nonnegative signed-comparison hysteresis magnitude. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `HYSTERESIS` | RW | 0x00000000 | 0 through HIGH-LOW under the applicable signed/unsigned comparison | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR0_META (`0x2364`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2364` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Committed channel 0 source and sequence readback. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 6:0 | `SOURCE` | RO | 0x00 | 0-127 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 30:7 | `SEQUENCE` | RO | 0x000000 | 0-0xFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31 | `RSV0` | RSV0 | 0 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR1_HYSTERESIS (`0x2368`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2368` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Channel 1 nonnegative signed-comparison hysteresis magnitude. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `HYSTERESIS` | RW | 0x00000000 | 0 through HIGH-LOW under the applicable signed/unsigned comparison | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

### SENSOR1_META (`0x236C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-236C` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-010 |
| Protection | No |
| Register behavior | Committed channel 1 source and sequence readback. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 6:0 | `SOURCE` | RO | 0x00 | 0-127 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 30:7 | `SEQUENCE` | RO | 0x000000 | 0-0xFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |
| 31 | `RSV0` | RSV0 | 0 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-010, ARCH-RTL010-001, ARCH-VAL-010 |

## 23. System Health Monitor

Eight synchronized health channels with qualification, polarity, active/sticky/recovered masks, and fault/event/interrupt controls.

| Attribute | Value |
|---|---|
| Address range | 0x2400-0x24FF |
| Primary owner | RTL-011 |
| Register count | 13 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x2400` | `HEALTH_CONTROL` | `REG-2400` |
| `0x2404` | `HEALTH_RAW_IN` | `REG-2404` |
| `0x2408` | `HEALTH_SYNC_IN` | `REG-2408` |
| `0x240C` | `HEALTH_QUAL_IN` | `REG-240C` |
| `0x2410` | `HEALTH_ACTIVE` | `REG-2410` |
| `0x2414` | `HEALTH_STICKY` | `REG-2414` |
| `0x2418` | `HEALTH_POLARITY` | `REG-2418` |
| `0x241C` | `HEALTH_FAULT_ENABLE` | `REG-241C` |
| `0x2420` | `HEALTH_EVENT_ENABLE` | `REG-2420` |
| `0x2424` | `HEALTH_IRQ_ENABLE` | `REG-2424` |
| `0x2428` | `HEALTH_QUAL_0_3` | `REG-2428` |
| `0x242C` | `HEALTH_QUAL_4_7` | `REG-242C` |
| `0x2430` | `RTL011_EVT_OVERFLOW_STATUS` | `REG-2430` |

### HEALTH_CONTROL (`0x2400`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2400` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Global health-monitor controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_RAW_IN (`0x2404`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2404` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Raw pad input values. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `RAW` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_SYNC_IN (`0x2408`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2408` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Synchronized input values. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `SYNC` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_QUAL_IN (`0x240C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-240C` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Qualified input values. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `QUALIFIED` | RO | 0x00 | Any defined 8-bit subset; reserved source bits zero | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_ACTIVE (`0x2410`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2410` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Polarity-adjusted active condition bitmap. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `ACTIVE` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_STICKY (`0x2414`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2414` |
| Access summary | Mixed: W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Sticky channel activation and recovery evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `ASSERTED` | W1C | 0x00 | 0-0xFF | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 15:8 | `RECOVERED` | W1C | 0x00 | Any defined 8-bit subset; reserved source bits zero | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_POLARITY (`0x2418`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2418` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Active polarity: zero active-low, one active-high. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `ACTIVE_HIGH` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_FAULT_ENABLE (`0x241C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-241C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | Yes |
| Register behavior | Per-channel fault-source enable. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `FAULT_ENABLE` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_EVENT_ENABLE (`0x2420`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2420` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Per-channel event enable. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `EVENT_ENABLE` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_IRQ_ENABLE (`0x2424`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2424` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Per-channel interrupt enable. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `IRQ_ENABLE` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_QUAL_0_3 (`0x2428`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2428` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Qualification intervals for channels 0-3. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `CH0_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 15:8 | `CH1_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 23:16 | `CH2_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:24 | `CH3_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### HEALTH_QUAL_4_7 (`0x242C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-242C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Qualification intervals for channels 4-7. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `CH4_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 15:8 | `CH5_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 23:16 | `CH6_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:24 | `CH7_MS` | RW | 0x00 | 0-0xFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

### RTL011_EVT_OVERFLOW_STATUS (`0x2430`)

| Property | Definition |
|---|---|
| Contract ID | `REG-2430` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-011 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-011, ARCH-RTL011-001, ARCH-VAL-011 |

## 24. Watchdog Manager

Protected service-window timing, key checking, recovery, response-mask, and persistent evidence.

| Attribute | Value |
|---|---|
| Address range | 0x3000-0x30FF |
| Primary owner | RTL-012 |
| Register count | 8 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x3000` | `WDOG_CONTROL` | `REG-3000` |
| `0x3004` | `WDOG_WINDOW_OPEN_US` | `REG-3004` |
| `0x3008` | `WDOG_TIMEOUT_US` | `REG-3008` |
| `0x300C` | `WDOG_SERVICE` | `REG-300C` |
| `0x3010` | `WDOG_STATUS` | `REG-3010` |
| `0x3014` | `WDOG_ELAPSED_US` | `REG-3014` |
| `0x3018` | `WDOG_RECOVERY` | `REG-3018` |
| `0x301C` | `RTL012_EVT_OVERFLOW_STATUS` | `REG-301C` |

### WDOG_CONTROL (`0x3000`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3000` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-012 |
| Protection | Yes |
| Register behavior | Protected watchdog enable, action, event, and interrupt controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 1 | `WINDOW_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 2 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 3 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 4 | `FAULT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 8:5 | `SAFETY_RESPONSE_MASK` | RW | 0x0 | Any defined 4-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 31:9 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |

### WDOG_WINDOW_OPEN_US (`0x3004`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3004` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-012 |
| Protection | No |
| Register behavior | Earliest valid service time in microseconds after prior service. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `WINDOW_OPEN_US` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |

### WDOG_TIMEOUT_US (`0x3008`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3008` |
| Access summary | RW |
| Register reset | 0x000F4240 |
| Owner | RTL-012 |
| Protection | No |
| Register behavior | Timeout interval in microseconds, default one second. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMEOUT_US` | RW | 0x000F4240 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |

### WDOG_SERVICE (`0x300C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-300C` |
| Access summary | WO-CMD |
| Register reset | 0x00000000 |
| Owner | RTL-012 |
| Protection | No |
| Register behavior | Watchdog service command. |
| Register-level side effect | Correct value services; any other value sets service error. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `SERVICE_KEY` | WO-CMD | 0x00000000 | 0-0xFFFFFFFF | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Correct value services; any other value sets service error. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |

### WDOG_STATUS (`0x3010`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3010` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-012 |
| Protection | No |
| Register behavior | Watchdog state and sticky evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLED` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 1 | `WINDOW_OPEN` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 2 | `SERVICE_ACCEPTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 3 | `EARLY_SERVICE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 4 | `BAD_SERVICE_KEY` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 5 | `TIMEOUT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 6 | `RESPONSE_PENDING` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 31:7 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |

### WDOG_ELAPSED_US (`0x3014`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3014` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-012 |
| Protection | No |
| Register behavior | Elapsed time since last valid service. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `ELAPSED_US` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |

### WDOG_RECOVERY (`0x3018`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3018` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-012 |
| Protection | Yes |
| Register behavior | Protected recovery/clear command after source condition is inactive. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `RECOVER` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one RECOVER command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |

### RTL012_EVT_OVERFLOW_STATUS (`0x301C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-301C` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-012 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-012, ARCH-RTL012-001, ARCH-VAL-012 |

## 25. Fault Manager

Fixed 17-source fault masks, classification, recoverability, primary-source selection, clear, and response generation.

| Attribute | Value |
|---|---|
| Address range | 0x3100-0x31FF |
| Primary owner | RTL-013 |
| Register count | 9 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x3100` | `FAULT_CONTROL` | `REG-3100` |
| `0x3104` | `FAULT_STATUS` | `REG-3104` |
| `0x3108` | `FAULT_CLASS` | `REG-3108` |
| `0x310C` | `FAULT_RESPONSE` | `REG-310C` |
| `0x3110` | `DEGRADED_STATUS` | `REG-3110` |
| `0x3114` | `FAULT_ACTIVE_SOURCE` | `REG-3114` |
| `0x3118` | `FAULT_LATCHED_SOURCE` | `REG-3118` |
| `0x311C` | `FAULT_RECOVERABLE_MASK` | `REG-311C` |
| `0x3120` | `RTL013_EVT_OVERFLOW_STATUS` | `REG-3120` |

### FAULT_CONTROL (`0x3100`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3100` |
| Access summary | Mixed: RW, WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-013 |
| Protection | Yes |
| Register behavior | Protected fault-manager enable and clear controls. |
| Register-level side effect | New fault detection dominates clear. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 1 | `CLEAR_ALL_REQ` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | New fault detection dominates clear. | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 31:2 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |

### FAULT_STATUS (`0x3104`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3104` |
| Access summary | Mixed: W1C, RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-013 |
| Protection | No |
| Register behavior | Aggregate fault latches and class validity. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `FAULT_ACTIVE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 1 | `MULTI_FAULT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 2 | `EVENT_PENDING` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 3 | `RESPONSE_PENDING` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 4 | `CLASS_VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 31:5 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |

### FAULT_CLASS (`0x3108`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3108` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-013 |
| Protection | No |
| Register behavior | Current deterministic fault class and primary source. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `CLASS` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 12:8 | `PRIMARY_SOURCE` | RO | 0x00 | 0-0x1F | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 13 | `MULTIPLE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 31:14 | `RSV0` | RSV0 | 0x00000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |

### FAULT_RESPONSE (`0x310C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-310C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-013 |
| Protection | Yes |
| Register behavior | Protected finite fault-response policy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `DEGRADED_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 1 | `SAFETY_RESPONSE_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 2 | `EVENT_ON_CLEAR` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 3 | `LATCH_UNTIL_HOST_CLEAR` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 7:4 | `SAFETY_OUTPUT_REQUEST_ENABLE` | RW | 0x0 | 0-15 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |

### DEGRADED_STATUS (`0x3110`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3110` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-013 |
| Protection | No |
| Register behavior | Degraded-entry and recovery evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ACTIVE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 1 | `ENTRY` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 2 | `RECOVERY_AVAILABLE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 3 | `RECOVERED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |

### FAULT_ACTIVE_SOURCE (`0x3114`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3114` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-013 |
| Protection | No |
| Register behavior | Current active fault-source vector. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `ACTIVE_SOURCE` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |

### FAULT_LATCHED_SOURCE (`0x3118`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3118` |
| Access summary | W1C |
| Register reset | 0x00000000 |
| Owner | RTL-013 |
| Protection | No |
| Register behavior | Retained fault-source evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `LATCHED_SOURCE` | W1C | 0x00000000 | Any subset of bits 0-16; bits 17-31 zero | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |

### FAULT_RECOVERABLE_MASK (`0x311C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-311C` |
| Access summary | CONST |
| Register reset | 0x00017FEF |
| Owner | RTL-013 |
| Protection | No |
| Register behavior | Fixed Architecture recoverability bitmap 0x00017FEF; it is not host-configurable. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `RECOVERABLE` | CONST | 0x00017FEF | Fixed reset/read value | Any register write is ACCESS_ERROR | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |

### RTL013_EVT_OVERFLOW_STATUS (`0x3120`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3120` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-013 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-013, ARCH-RTL013-001, ARCH-VAL-013 |

## 26. Interlock Engine

Eight atomically committed four-term expressions with fixed operators, guards, response masks, and violation evidence.

| Attribute | Value |
|---|---|
| Address range | 0x3200-0x32FF |
| Primary owner | RTL-014 |
| Register count | 10 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x3200` | `ILOCK_CONTROL` | `REG-3200` |
| `0x3204` | `ILOCK_STATUS` | `REG-3204` |
| `0x3208` | `ILOCK_ENTRY_SELECT` | `REG-3208` |
| `0x320C` | `ILOCK_STAGE_TERMS` | `REG-320C` |
| `0x3210` | `ILOCK_STAGE_LOGIC` | `REG-3210` |
| `0x3214` | `ILOCK_STAGE_GUARD` | `REG-3214` |
| `0x3218` | `ILOCK_STAGE_ENABLE` | `REG-3218` |
| `0x321C` | `ILOCK_VALIDATE_COMMIT` | `REG-321C` |
| `0x3220` | `ILOCK_ACTIVE_RESULT` | `REG-3220` |
| `0x3224` | `RTL014_EVT_OVERFLOW_STATUS` | `REG-3224` |

### ILOCK_CONTROL (`0x3200`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3200` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-014 |
| Protection | Yes |
| Register behavior | Global interlock enable and diagnostics controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 1 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 2 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |

### ILOCK_STATUS (`0x3204`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3204` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-014 |
| Protection | No |
| Register behavior | Aggregate interlock state and sticky validation/violation evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `VIOLATION_ACTIVE` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 15:8 | `VIOLATION_STICKY` | W1C | 0x00 | 0-0xFF | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 16 | `COMMIT_COMPLETE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 17 | `COMMIT_REJECTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 31:18 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |

### ILOCK_ENTRY_SELECT (`0x3208`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3208` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-014 |
| Protection | No |
| Register behavior | Selects staged/readback entry 0-7. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 2:0 | `ENTRY` | RW | 0x0 | 0-7 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |

### ILOCK_STAGE_TERMS (`0x320C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-320C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-014 |
| Protection | No |
| Register behavior | Four staged enumerated term IDs. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `TERM0` | RW | 0x00 | 0-31 or 37; 32-36 and 38-255 reserved | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 15:8 | `TERM1` | RW | 0x00 | 0-31 or 37; 32-36 and 38-255 reserved | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 23:16 | `TERM2` | RW | 0x00 | 0-31 or 37; 32-36 and 38-255 reserved | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 31:24 | `TERM3` | RW | 0x00 | 0-31 or 37; 32-36 and 38-255 reserved | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |

### ILOCK_STAGE_LOGIC (`0x3210`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3210` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-014 |
| Protection | No |
| Register behavior | Staged inversion and Boolean operator. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `INVERT_MASK` | RW | 0x0 | Any defined 4-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 6:4 | `OPERATOR` | RW | 0x0 | 0 AND; 1 OR; 2 three-of-four; 3 (t0&t1)\|(t2&t3); 4-7 reserved | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 31:7 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |

### ILOCK_STAGE_GUARD (`0x3214`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3214` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-014 |
| Protection | No |
| Register behavior | Staged guard destination mask. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `GUARD_MASK` | RW | 0x00 | 0x01-0xFF for an enabled entry | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |

### ILOCK_STAGE_ENABLE (`0x3218`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3218` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-014 |
| Protection | No |
| Register behavior | Staged entry enable and evidence policy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 1 | `LATCH_VIOLATION` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 2 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 3 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |

### ILOCK_VALIDATE_COMMIT (`0x321C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-321C` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-014 |
| Protection | Yes |
| Register behavior | Protected global validation and atomic commit of all staged entries. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `COMMIT_ALL` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one COMMIT_ALL command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |

### ILOCK_ACTIVE_RESULT (`0x3220`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3220` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-014 |
| Protection | No |
| Register behavior | Current evaluated entry results and guard permissions. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `ENTRY_TRUE` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 15:8 | `GUARD_ALLOWED` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 31:16 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |

### RTL014_EVT_OVERFLOW_STATUS (`0x3224`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3224` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-014 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-014, ARCH-RTL014-001, ARCH-VAL-014 |

## 27. Lost-Link Supervisor

Eight activity monitors with qualification, timeout, recovery, response masks, and bounded test injection.

| Attribute | Value |
|---|---|
| Address range | 0x3300-0x33FF |
| Primary owner | RTL-015 |
| Register count | 10 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x3300` | `LLINK_CONTROL` | `REG-3300` |
| `0x3304` | `LLINK_STATUS` | `REG-3304` |
| `0x3308` | `LLINK_MONITOR_SELECT` | `REG-3308` |
| `0x330C` | `LLINK_MONITOR_CONTROL` | `REG-330C` |
| `0x3310` | `LLINK_QUALIFY_US` | `REG-3310` |
| `0x3314` | `LLINK_TIMEOUT_US` | `REG-3314` |
| `0x3318` | `LLINK_RECOVERY_US` | `REG-3318` |
| `0x331C` | `LLINK_ELAPSED_US` | `REG-331C` |
| `0x3320` | `LLINK_ACTIVITY_INJECT` | `REG-3320` |
| `0x3324` | `RTL015_EVT_OVERFLOW_STATUS` | `REG-3324` |

### LLINK_CONTROL (`0x3300`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3300` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-015 |
| Protection | Yes |
| Register behavior | Global lost-link enable and aggregate event/interrupt controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 1 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 2 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |

### LLINK_STATUS (`0x3304`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3304` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-015 |
| Protection | No |
| Register behavior | Per-monitor current lost and sticky recovery/evidence status. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `LOST_ACTIVE` | RO | 0x00 | 0-0xFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 15:8 | `LOST_STICKY` | W1C | 0x00 | 0-0xFF | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 23:16 | `RECOVERED` | W1C | 0x00 | Any defined 8-bit subset; reserved source bits zero | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 31:24 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |

### LLINK_MONITOR_SELECT (`0x3308`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3308` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-015 |
| Protection | No |
| Register behavior | Selects monitor 0-7 for configuration. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 2:0 | `MONITOR` | RW | 0x0 | 0-7 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |

### LLINK_MONITOR_CONTROL (`0x330C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-330C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-015 |
| Protection | Yes |
| Register behavior | Selected monitor enable and action policy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 1 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 2 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 3 | `FAULT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 7:4 | `SAFETY_RESPONSE_MASK` | RW | 0x0 | Any defined 4-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |

### LLINK_QUALIFY_US (`0x3310`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3310` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-015 |
| Protection | No |
| Register behavior | Selected monitor activity-qualification interval. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `QUALIFY_US` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |

### LLINK_TIMEOUT_US (`0x3314`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3314` |
| Access summary | RW |
| Register reset | 0x000F4240 |
| Owner | RTL-015 |
| Protection | No |
| Register behavior | Selected monitor timeout interval. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `TIMEOUT_US` | RW | 0x000F4240 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |

### LLINK_RECOVERY_US (`0x3318`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3318` |
| Access summary | RW |
| Register reset | 0x000186A0 |
| Owner | RTL-015 |
| Protection | No |
| Register behavior | Selected monitor valid-activity recovery interval. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `RECOVERY_US` | RW | 0x000186A0 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |

### LLINK_ELAPSED_US (`0x331C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-331C` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-015 |
| Protection | No |
| Register behavior | Selected monitor elapsed time since qualified activity. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `ELAPSED_US` | RO | 0x00000000 | 0-0xFFFFFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |

### LLINK_ACTIVITY_INJECT (`0x3320`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3320` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-015 |
| Protection | No |
| Register behavior | Qualified-test-only selected-monitor injection: value 1 injects one activity pulse, value 2 injects loss evidence, and value 3 is reserved. Natural activity or loss retains priority. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 1:0 | `HEARTBEAT` | WO-CMD | 0x0 | 0 no action; 1 activity pulse; 2 loss evidence; 3 reserved; nonzero requires qualified test-active | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one HEARTBEAT command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 31:2 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |

### RTL015_EVT_OVERFLOW_STATUS (`0x3324`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3324` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-015 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-015, ARCH-RTL015-001, ARCH-VAL-015 |

## 28. Safety Output Controller

Four logical safety channels with fixed source authorization, interlock gating, polarity, latching, inhibit, and test-safe status.

| Attribute | Value |
|---|---|
| Address range | 0x3400-0x34FF |
| Primary owner | RTL-016 |
| Register count | 8 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x3400` | `SAFETY_CONTROL` | `REG-3400` |
| `0x3404` | `SAFETY_STATUS` | `REG-3404` |
| `0x3408` | `SAFETY_CHANNEL_SELECT` | `REG-3408` |
| `0x340C` | `SAFETY_CHANNEL_CONTROL` | `REG-340C` |
| `0x3410` | `SAFETY_RESPONSE_MASK` | `REG-3410` |
| `0x3414` | `SAFETY_INTERLOCK_MASK` | `REG-3414` |
| `0x3418` | `SAFETY_CHANNEL_STATUS` | `REG-3418` |
| `0x341C` | `RTL016_EVT_OVERFLOW_STATUS` | `REG-341C` |

### SAFETY_CONTROL (`0x3400`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3400` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-016 |
| Protection | Yes |
| Register behavior | Global protected safety-output controller enable and event policy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 1 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 2 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |

### SAFETY_STATUS (`0x3404`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3404` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-016 |
| Protection | No |
| Register behavior | Aggregate safety-output status and sticky violations. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `COMMANDED` | RO | 0x0 | 0-15 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 7:4 | `EFFECTIVE` | RO | 0x0 | 0-15 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 11:8 | `INHIBITED` | RO | 0x0 | 0-15 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 15:12 | `FAULTED` | RO | 0x0 | 0-15 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 19:16 | `EVENT` | W1C | 0x0 | 0-15 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 31:20 | `RSV0` | RSV0 | 0x000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |

### SAFETY_CHANNEL_SELECT (`0x3408`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3408` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-016 |
| Protection | No |
| Register behavior | Selects channel 0-3 for configuration/readback. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 1:0 | `CHANNEL` | RW | 0x0 | 0-3 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 31:2 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |

### SAFETY_CHANNEL_CONTROL (`0x340C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-340C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000002 |
| Owner | RTL-001 / RTL-016 |
| Protection | Yes |
| Register behavior | Selected channel protected enable and polarity policy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 1 | `ACTIVE_HIGH` | RW | 1 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 2 | `LATCH_RESPONSE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |

### SAFETY_RESPONSE_MASK (`0x3410`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3410` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-016 |
| Protection | Yes |
| Register behavior | Selected channel authorized finite response-source mask. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `RESPONSE_SOURCE_MASK` | RW | 0x00000000 | Any subset of 0xFFFF0101; all other bits reserved | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |

### SAFETY_INTERLOCK_MASK (`0x3414`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3414` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-016 |
| Protection | Yes |
| Register behavior | Required interlock-permission mask for selected channel. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `REQUIRED_INTERLOCKS` | RW | 0x00 | Any defined 8-bit subset; reserved source bits zero | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |

### SAFETY_CHANNEL_STATUS (`0x3418`)

| Property | Definition |
|---|---|
| Contract ID | `REG-3418` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x000000CC |
| Owner | RTL-016 |
| Protection | No |
| Register behavior | Detailed selected channel commanded/effective/inhibit/fault/reset state. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `COMMAND_REQUEST` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 1 | `EFFECTIVE_OUTPUT` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 2 | `DISABLED` | RO | 1 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 3 | `OBSERVATIONAL_INHIBIT` | RO | 1 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 4 | `INTERLOCK_INHIBIT` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 5 | `FAULT_INHIBIT` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 6 | `RESET_ACTIVE` | RO | 1 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 7 | `TEST_INHIBIT` | RO | 1 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |

### RTL016_EVT_OVERFLOW_STATUS (`0x341C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-341C` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-016 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-016, ARCH-RTL016-001, ARCH-VAL-016 |

## 29. Mask-Defined User Logic Island

Revision A inert functional profile with diagnostic input capture and bounded diagnostic mailboxes.

| Attribute | Value |
|---|---|
| Address range | 0x4000-0x40FF |
| Primary owner | RTL-022 |
| Register count | 20 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x4000` | `ULI_CONTROL` | `REG-4000` |
| `0x4004` | `ULI_STATUS` | `REG-4004` |
| `0x4008` | `ULI_PARAM0` | `REG-4008` |
| `0x400C` | `ULI_PARAM1` | `REG-400C` |
| `0x4010` | `ULI_PARAM2` | `REG-4010` |
| `0x4014` | `ULI_PARAM3` | `REG-4014` |
| `0x4018` | `ULI_PARAM4` | `REG-4018` |
| `0x401C` | `ULI_PARAM5` | `REG-401C` |
| `0x4020` | `ULI_PARAM6` | `REG-4020` |
| `0x4024` | `ULI_PARAM7` | `REG-4024` |
| `0x4028` | `ULI_IN_LEVEL` | `REG-4028` |
| `0x402C` | `ULI_IN_DATA` | `REG-402C` |
| `0x4030` | `ULI_IN_PUSH` | `REG-4030` |
| `0x4034` | `ULI_OUT_LEVEL` | `REG-4034` |
| `0x4038` | `ULI_OUT_DATA` | `REG-4038` |
| `0x403C` | `ULI_OUT_POP` | `REG-403C` |
| `0x4040` | `ULI_IO_DIRECTION` | `REG-4040` |
| `0x4044` | `ULI_IO_INPUT` | `REG-4044` |
| `0x4048` | `ULI_IO_OUTPUT` | `REG-4048` |
| `0x404C` | `RTL022_EVT_OVERFLOW_STATUS` | `REG-404C` |

### ULI_CONTROL (`0x4000`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4000` |
| Access summary | Mixed: RW, WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-022 |
| Protection | Yes |
| Register behavior | Revision A inert-profile control. ENABLE and IRQ_ENABLE have the sole legal value zero; RESET_REQ and diagnostic EVENT_ENABLE remain available. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 1 | `RESET_REQ` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one RESET_REQ command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 2 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 3 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_STATUS (`0x4004`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4004` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-022 |
| Protection | No |
| Register behavior | User-logic readiness, mailboxes, and sticky violation evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLED` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 1 | `READY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 2 | `IN_MAILBOX_NOT_EMPTY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 3 | `OUT_MAILBOX_NOT_EMPTY` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 4 | `IN_MAILBOX_FULL` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 5 | `OUT_MAILBOX_FULL` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 6 | `VIOLATION` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 7 | `RESET_COMPLETE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_PARAM0 (`0x4008`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4008` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-022 |
| Protection | No |
| Register behavior | Revision A inert functional parameter 0; reads zero and rejects every nonzero write. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PARAM0` | RW | 0x00000000 | 0 only in Revision A | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_PARAM1 (`0x400C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-400C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-022 |
| Protection | No |
| Register behavior | Revision A inert functional parameter 1; reads zero and rejects every nonzero write. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PARAM1` | RW | 0x00000000 | 0 only in Revision A | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_PARAM2 (`0x4010`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4010` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-022 |
| Protection | No |
| Register behavior | Revision A inert functional parameter 2; reads zero and rejects every nonzero write. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PARAM2` | RW | 0x00000000 | 0 only in Revision A | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_PARAM3 (`0x4014`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4014` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-022 |
| Protection | No |
| Register behavior | Revision A inert functional parameter 3; reads zero and rejects every nonzero write. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PARAM3` | RW | 0x00000000 | 0 only in Revision A | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_PARAM4 (`0x4018`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4018` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-022 |
| Protection | No |
| Register behavior | Revision A inert functional parameter 4; reads zero and rejects every nonzero write. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PARAM4` | RW | 0x00000000 | 0 only in Revision A | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_PARAM5 (`0x401C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-401C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-022 |
| Protection | No |
| Register behavior | Revision A inert functional parameter 5; reads zero and rejects every nonzero write. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PARAM5` | RW | 0x00000000 | 0 only in Revision A | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_PARAM6 (`0x4020`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4020` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-022 |
| Protection | No |
| Register behavior | Revision A inert functional parameter 6; reads zero and rejects every nonzero write. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PARAM6` | RW | 0x00000000 | 0 only in Revision A | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_PARAM7 (`0x4024`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4024` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-022 |
| Protection | No |
| Register behavior | Revision A inert functional parameter 7; reads zero and rejects every nonzero write. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `PARAM7` | RW | 0x00000000 | 0 only in Revision A | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_IN_LEVEL (`0x4028`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4028` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-022 |
| Protection | No |
| Register behavior | Input mailbox occupancy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 2:0 | `LEVEL` | RO | 0x0 | 0-7 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_IN_DATA (`0x402C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-402C` |
| Access summary | RW |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-022 |
| Protection | No |
| Register behavior | Staged input-mailbox word. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MAILBOX_DATA` | RW | 0x00000000 | 0-0xFFFFFFFF | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_IN_PUSH (`0x4030`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4030` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-022 |
| Protection | No |
| Register behavior | Pushes one staged input-mailbox word. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `PUSH` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one PUSH command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_OUT_LEVEL (`0x4034`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4034` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-022 |
| Protection | No |
| Register behavior | Output-mailbox occupancy; fixed zero in the inert Revision A profile. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 2:0 | `LEVEL` | RO | 0x0 | 0 only in Revision A | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_OUT_DATA (`0x4038`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4038` |
| Access summary | RO |
| Register reset | 0x00000000 |
| Owner | RTL-022 |
| Protection | No |
| Register behavior | Output-mailbox data; fixed zero in the inert Revision A profile. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 31:0 | `MAILBOX_DATA` | RO | 0x00000000 | 0 only in Revision A | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_OUT_POP (`0x403C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-403C` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-022 |
| Protection | No |
| Register behavior | Output-mailbox pop command; rejected as empty in the inert Revision A profile. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `POP` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one POP command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 31:1 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_IO_DIRECTION (`0x4040`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4040` |
| Access summary | Mixed: CONST, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-022 / RTL-024 |
| Protection | No |
| Register behavior | Fixed zero output-enable direction; all four user positions are diagnostic inputs in Revision A. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `OUTPUT_DIRECTION` | CONST | 0x0 | Fixed reset/read value | Any register write is ACCESS_ERROR | Reads the stored or fixed field value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022, ARCH-MOD-024, ARCH-RTL024-001, ARCH-VAL-024 |

### ULI_IO_INPUT (`0x4044`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4044` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-022 |
| Protection | No |
| Register behavior | Synchronized/qualified user-I/O input values. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `INPUT` | RO | 0x0 | 0-15 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### ULI_IO_OUTPUT (`0x4048`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4048` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-022 |
| Protection | No |
| Register behavior | Revision A inert output request. OUTPUT_REQUEST has the sole legal value zero. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `OUTPUT_REQUEST` | RW | 0x0 | 0 only in Revision A | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

### RTL022_EVT_OVERFLOW_STATUS (`0x404C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-404C` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-022 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-022, ARCH-RTL022-001, ARCH-VAL-022 |

## 30. User-Configurable Routing Logic

Sixteen staged signal-route entries with exact source/destination authorization, mode, conflict, and activity evidence.

| Attribute | Value |
|---|---|
| Address range | 0x4100-0x41FF |
| Primary owner | RTL-023 |
| Register count | 11 |
| Unimplemented offsets | DECODE_ERROR; no side effect |

| Offset | Register | Contract ID |
|---:|---|---|
| `0x4100` | `UROUTE_CONTROL` | `REG-4100` |
| `0x4104` | `UROUTE_STATUS` | `REG-4104` |
| `0x4108` | `UROUTE_ENTRY_SELECT` | `REG-4108` |
| `0x410C` | `UROUTE_STAGE_SOURCE` | `REG-410C` |
| `0x4110` | `UROUTE_STAGE_DEST` | `REG-4110` |
| `0x4114` | `UROUTE_STAGE_CONTROL` | `REG-4114` |
| `0x4118` | `UROUTE_VALIDATE_COMMIT` | `REG-4118` |
| `0x411C` | `UROUTE_ACTIVE_SOURCE` | `REG-411C` |
| `0x4120` | `UROUTE_ACTIVE_DEST` | `REG-4120` |
| `0x4124` | `UROUTE_ENTRY_STATUS` | `REG-4124` |
| `0x4128` | `RTL023_EVT_OVERFLOW_STATUS` | `REG-4128` |

### UROUTE_CONTROL (`0x4100`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4100` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-023 |
| Protection | Yes |
| Register behavior | Global user-routing enable and diagnostics controls. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 1 | `EVENT_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 2 | `IRQ_ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:3 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

### UROUTE_STATUS (`0x4104`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4104` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-023 |
| Protection | No |
| Register behavior | User-routing state and sticky commit/violation evidence. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ACTIVE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 1 | `COMMIT_COMPLETE` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 2 | `COMMIT_REJECTED` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 3 | `FORBIDDEN_DEST` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 4 | `CONFLICT` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 15:5 | `RSV0` | RSV0 | 0x000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:16 | `VIOLATION_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

### UROUTE_ENTRY_SELECT (`0x4108`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4108` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-023 |
| Protection | No |
| Register behavior | Selects route entry 0-15. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 3:0 | `ENTRY` | RW | 0x0 | 0-15 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

### UROUTE_STAGE_SOURCE (`0x410C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-410C` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-023 |
| Protection | No |
| Register behavior | Staged enumerated source endpoint. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `SOURCE_ID` | RW | 0x00 | 0-31 or 37, subject to source/destination authorization | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

### UROUTE_STAGE_DEST (`0x4110`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4110` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-023 |
| Protection | No |
| Register behavior | Staged enumerated destination endpoint. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `DEST_ID` | RW | 0x00 | 0-24, subject to source/destination authorization | Validated at accepted write or staged-object commit; invalid value rejects atomically | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

### UROUTE_STAGE_CONTROL (`0x4114`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4114` |
| Access summary | Mixed: RW, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-023 |
| Protection | No |
| Register behavior | Staged route enable, inversion, and edge/level policy. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ENABLE` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 1 | `INVERT` | RW | 0 | 0 or 1 | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 3:2 | `MODE` | RW | 0x0 | 0 level; 1 rising pulse; 2 falling pulse; 3 either-edge pulse | Value and all cross-field constraints validated before atomic acceptance | Reads the stored or fixed field value | Updates only this stored field; staged fields do not alter active state until commit | Reset, then accepted write/commit, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:4 | `RSV0` | RSV0 | 0x0000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

### UROUTE_VALIDATE_COMMIT (`0x4118`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4118` |
| Access summary | Mixed: WO-CMD, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-001 / RTL-023 |
| Protection | Yes |
| Register behavior | Validates and commits selected entry. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `VALIDATE_COMMIT` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one VALIDATE_COMMIT command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 1 | `DISABLE_ENTRY` | WO-CMD | 0 | 0 or 1 | Undefined encoding, unmet precondition, or nonzero reserved bit rejects with no command pulse | Reads zero | Issues one DISABLE_ENTRY command pulse | Reset/disable or inhibit, then accepted command, then ordinary progression | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:2 | `RSV0` | RSV0 | 0x00000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-001, ARCH-RTL001-001, ARCH-VAL-001, ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

### UROUTE_ACTIVE_SOURCE (`0x411C`)

| Property | Definition |
|---|---|
| Contract ID | `REG-411C` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-023 |
| Protection | No |
| Register behavior | Active selected route source. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `SOURCE_ID` | RO | 0x00 | 0-31 or 37 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

### UROUTE_ACTIVE_DEST (`0x4120`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4120` |
| Access summary | Mixed: RO, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-023 |
| Protection | No |
| Register behavior | Active selected route destination. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 7:0 | `DEST_ID` | RO | 0x00 | 0-24 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:8 | `RSV0` | RSV0 | 0x000000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

### UROUTE_ENTRY_STATUS (`0x4124`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4124` |
| Access summary | Mixed: RO, W1C, RSV0 |
| Register reset | 0x00000000 |
| Owner | RTL-023 |
| Protection | No |
| Register behavior | Selected route active/valid/error and activity count. |
| Register-level side effect | None |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `ACTIVE` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 1 | `VALID` | RO | 0 | 0 or 1 | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 2 | `ERROR` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 15:3 | `RSV0` | RSV0 | 0x0000 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:16 | `ACTIVITY_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads the coherent selected/snapshot value described by the register | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

### RTL023_EVT_OVERFLOW_STATUS (`0x4128`)

| Property | Definition |
|---|---|
| Contract ID | `REG-4128` |
| Access summary | Mixed: W1C, RSV0, RO |
| Register reset | 0x00000000 |
| Owner | RTL-023 |
| Protection | No |
| Register behavior | Sticky evidence and saturating count for records lost while the owning module event-pending slot was occupied. |
| Register-level side effect | Writing one to EVENT_OVERFLOW requests clear; DROP_COUNT is read-only. |

| Bits | Field | Access | Reset | Legal values/range | Write validation | Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
|---:|---|---|---:|---|---|---|---|---|---|
| 0 | `EVENT_OVERFLOW` | W1C | 0 | 0 or 1 | One requests clear; zero has no effect | Reads current retained value | Requests clear of selected sticky evidence only | Reset/disable, then new evidence, then clear | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 7:1 | `RSV0` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 23:8 | `DROP_COUNT` | RO | 0x0000 | 0-0xFFFF | Pure-RO register writes reject; in a mixed register host writes zero to this field and nonzero rejects | Reads current hardware value | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |
| 31:24 | `RSV1` | RSV0 | 0x00 | 0 only | A written one rejects the entire 32-bit write | Reads zero | None | Architecture producer priority; reset dominates | ARCH-MOD-023, ARCH-RTL023-001, ARCH-VAL-023 |

## 31. Proxy, Snapshot, Pop, Staging, and Commit Semantics

| ID | Contract |
|---|---|
| REG-COH-001 | A selector register chooses one bounded object. Selector writes do not change staged or active object contents. |
| REG-COH-002 | Staged fields are independently readable and writable. An explicit validate/commit command revalidates the complete object and atomically replaces active state only on success. |
| REG-COH-003 | A rejected commit preserves the complete prior active object and the complete staged object, records the first error, and emits no partial control update. |
| REG-COH-004 | A snapshot command captures one coherent object. Data reads do not advance the source. Pop removes exactly the snapped oldest object and invalidates the snapshot. |
| REG-COH-005 | Empty snapshot/pop, full push, disabled push, and malformed command preconditions reject without pointer, occupancy, active-state, or storage change. |
| REG-COH-006 | Queue simultaneous push/pop behavior is owned by Architecture Appendix F.2. Event-store overwrite is the sole queue exception and is owned by ARCH-EVT-005 through ARCH-EVT-007. |
| REG-COH-007 | Event-store overflow event 0x007F has priority over producer-slot overflow event 0x007E. Pending reports coalesce; an internally generated overflow record does not recursively increment or report overflow. |
| REG-COH-008 | Active route readback uses eight source bits and five destination bits. Upper register bits are reserved zero and never contain alternate 32-bit identifiers. |
| REG-COH-009 | Physical shared-buffer addresses are not host-visible. Host queue/mailbox registers expose only client-owned coherent state and commands defined here. |

## 32. Reset and Safe-State Register Contract

All reset values are stated in the register definitions. External/system reset restores every register-owned configuration field, sticky item, counter, selector, stage, snapshot, and command state. A module reset clears that module's functional status, counters, snapshots, pointers, and outstanding commands but preserves configuration stored by RTL-001 unless RTL-001 is included. Physical shared-buffer words and event-store array words need not be cleared; their valid state is cleared and invalid contents are never exposed.

Timestamp raw time starts at zero and runs after qualified reset release. Operational enables, transmitters, routes, user outputs, watchdog actions, interlocks, and logical safety outputs reset inactive. `TIME_CONTROL.ENABLE` and `EVT_CONTROL.OVERWRITE_OLDEST` reset and remain one. Safety polarity defaults active-high, while reset, observation, and test inhibit indications report asserted until their corresponding Architecture conditions release.

## 33. Generated Register Artifacts

| ID | Required generated artifact | Content |
|---|---|---|
| REG-GENART-001 | `dfc_registers_pkg.sv` | Offsets, masks, shifts, access classes, reset values, legal-value predicates, command encodings, and compile-time checks |
| REG-GENART-002 | External-host definitions | SPI status values, register constants, typed fields, protected-write helpers, counter-clear helpers, snapshot/pop helpers, and staging/commit helpers |
| REG-GENART-003 | Verification model | Exact reset, access, legality, side-effect, priority, and negative-access expectations for every field |
| REG-GENART-004 | Machine-readable register source | Blocks, registers, fields, owners, access, reset, protection, legal values, validation, read behavior, write behavior, side effects, priorities, and Architecture sources |
| REG-GENART-005 | Build manifest | BUILD_ID parameter, register-source digest, generator version, and generated-artifact digests; no document-history state |

Generation shall fail for duplicate names or offsets, unaligned offsets, block overrun, overlapping or incomplete bit coverage, nonzero reserved reset, unknown access class, missing field attribute, illegal reset value, unresolved Architecture identifier, or a generated packed-structure width mismatch. The generated mapping shall specifically prove that `SAFETY_CHANNEL_CONTROL.ACTIVE_HIGH` is present in the Architecture-defined 52-bit `dfc_rtl016_control_t`. Hand-copied register constants are prohibited.

## 34. Register Population

This specification defines **314 registers** and **861 field rows**. The count includes each concrete `RTLxxx_EVT_OVERFLOW_STATUS` instance and every reserved field row; it does not multiply or infer undocumented fields from a template.
