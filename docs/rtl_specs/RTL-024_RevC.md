# RTL-024 Module Specification — Dragon Core Top-Level Integration

**Revision:** C (authored fresh against the `-002` baseline; the `-001`-era
Rev A/B specifications are not content sources, only structural reference)
**Status:** Derived artifact per `RCA-DFC-CHTR-002` SS3.3 (CHTR-DOC-006: no
new behavior defined here). Every normative claim cites ARCH-002, REG-002,
RTL-STD-002, or VP-002.

## 1. Identity and role

RTL-024 is the Dragon Core **technology-independent top-level module**
(`ARCH-GEN-002`): it instantiates RTL-001 through RTL-023 exactly once and
is the **sole functional integration top** (`RTLSTD-MOD-011`). It has only
wrapper/platform-facing external ports — 33 of them (ARCH-002 "RTL-024 -
Dragon Core Top-Level Integration"). Every RTL-001..023 connection,
generated core clock/reset net, DRI, control/status, event, interrupt,
fault, safety-request, canonical-message, and shared-buffer interface is
an **internal net RTL-024 owns**, enumerated by `ARCH-CONN-001` through
`ARCH-CONN-012`. It is a mandatory, host-ready-at-reset module (Appendix
D.1 bit 23) with no `module_reset_i` — system reset only.

## 2. External ports (33 total)

Per `RTLSTD-MOD-012`: RTL-024's external ports are limited to the
wrapper/platform-facing logical ports in the Architecture catalog;
child-to-child connections are never exposed as RTL-024 ports. Groups, per
the catalog:

- **Clock/reset:** `core_clk_i` (nominal 50 MHz continuous, `ARCH-CLK-001`),
  `por_n_i` (asynchronous, internal wrapper input — not a pad).
- **SPI:** `spi_sclk_i`, `spi_cs_n_i`, `spi_mosi_i`, `spi_miso_o`,
  `spi_miso_oe_o` — Mode 0, low idle; MISO zero when output-enable low.
- **Host interrupt:** `host_irq_n_o` — high in reset or with no enabled
  pending source.
- **GPIO:** `gpio_i`/`gpio_o`/`gpio_oe_o` (8 each) — zero in
  reset/disable/test.
- **ARINC:** `arinc_rx_i`, `arinc_tx_ctrl_o`, `arinc_rx_adapter_error_i`,
  `arinc_tx_adapter_error_i`.
- **CAN:** `can_rx_i`, `can_tx_o`, `can_transceiver_error_i` (recessive
  high idle).
- **UART:** `uart_rx_i`, `uart_tx_o` (idle high).
- **Monitoring inputs:** `rotor_i`, `engine_i`, `pulse_i[1:0]`,
  `health_i[7:0]` — all asynchronous, sampled only through their named CDC
  structure (`CDC-PULSE`, `CDC-HEALTH`).
- **Safety:** `safety_out_o[3:0]` — inactive under every `ARCH-SAFE`
  inhibit.
- **User I/O:** `user_i/o/oe[3:0]` — Revision A: diagnostic capture only on
  input, constant zero on output/OE.
- **Production test:** `test_enable_i`, `test_clock_i`, `test_data_i/o`,
  `test_data_oe_o` — TEST_CLK domain; ignored unless authorized.

Reserved inputs tied safely, no functional port floats, widths/directions
match Appendix A exactly (`VP-INT-001`).

## 3. Internal connection classes (owned, not exposed)

RTL-024 owns and connects, per `ARCH-CONN-001` through `-012`:

| Class | Contract |
|---|---|
| `ARCH-CONN-001` Core clock/reset | One clock tree, qualified reset; no child-to-child clock/reset generation |
| `ARCH-CONN-002` DRI | One request/response channel, RTL-024 host executor ↔ RTL-001 |
| `ARCH-CONN-003` Control/status | Registered Appendix B packed structures, RTL-001 ↔ each module |
| `ARCH-CONN-004` Operating controls | RTL-002 → all applicable modules: operating state, observation state, effective/optional enables, module resets |
| `ARCH-CONN-005` Interrupt vector | Fixed 32-position vector into RTL-003; reserved positions tied low |
| `ARCH-CONN-006` Event array | 24 independent valid/ready/record channels into RTL-005 |
| `ARCH-CONN-007` Fault vector | Fixed 32-position vector into RTL-013; bits 17–31 tied low |
| `ARCH-CONN-008` Safety request lanes | 4 distinct `dfc_safety_response_req_t` lanes into RTL-016; no pre-authorization merging |
| `ARCH-CONN-009` Canonical messages | 5 source + 5 destination valid/ready channels via RTL-021 |
| `ARCH-CONN-010` Shared buffer | 7 typed request/response channels, RTL-017..022 + RTL-024 SPI client → RTL-024 service |
| `ARCH-CONN-011` Qualified external signals | Only synchronized/protocol-recovered signals leave RTL-024 toward RTL-006..011, 017, 019, 020, 022 |
| `ARCH-CONN-012` External outputs | RTL-024 pad-safe gates apply reset/disable/observation/test/invalid-state gating for RTL-006, 016, 018–020, 022 |

Per `RTLSTD-MOD-013`/`-014`: every one of these is an explicit internal net
with one producer and the Architecture-defined consumer(s) — RTL-024 never
uses a hierarchical reference into child state; it connects only via
declared child ports and shared package types.

## 4. Module reset distribution

RTL-024 (via RTL-002, per the catalog's `module_reset_o[23:0]`) implements:

- `ARCH-RST-004` (module reset): synchronous one-hot request, asserted
  ≥4 CORE_CLK cycles, clears state per Appendix F, requires two consecutive
  ready cycles before completion. Bits 0 (RTL-001) and 23 (RTL-024 itself)
  have no child local-reset consumer — both are system-reset-only per
  Appendix D.1.
- `ARCH-RST-005` (system reset, protected command): resets RTL-002 through
  RTL-024 and clears RTL-001 configuration one CORE_CLK after reset
  completion is recorded.
- `ARCH-RST-006` (safety-domain reset, protected command): resets RTL-012
  through RTL-016 state and forces every safety output inactive; does not
  touch unrelated modules.

## 5. RTL-024's own derivation contract

`ARCH-RTL024-001`: RTL-024 instantiates RTL-001 through RTL-023, connects
every Appendix A interface, implements ARCH-002 SS5–7, 12, and 14, and owns
all pad-safe gates. **Ready** requires reset, host mailboxes, DRI, shared
buffer, and test controller all initialized. **Fault** is (host timeout OR
internal error) OR shared-buffer internal error OR reset/clock/test
integration error.

RTL-024's fault-source bit 15 (Appendix C.6: "Mask-defined user-logic
error", producer RTL-022, class `0x7F` nonrecoverable) and interrupt/event
sources at C.4 bits 20–23 (Host Interface, Configuration Error owned by
RTL-001, Clock/Reset Integration, Production Test) are all RTL-024-owned
or RTL-024-adjacent — confirm against the current `dfc_interrupt_pkg`/
`dfc_events_pkg` output (generated by `tools/pkggen/extract_irqfault.py`)
rather than re-deriving bit positions here.

## 6. Compile-order and technology independence

Per `RTLSTD-ORG-007`: FPGA and ASIC builds share the same
technology-independent RTL-001 through RTL-024 source, differing only in
Architecture-defined wrappers and implementation files. Technology
primitives, pad cells, memory macros, clock cells, and vendor primitives
never appear in RTL-024's functional body (`RTLSTD-MOD-008`) — they belong
in the FPGA/ASIC wrapper layer (`RTL-STD-002` SS26).

## 7. Verification obligations

Minimum required VP-002 case families for RTL-024:

- **`VP-INT-001` through `VP-INT-012`** (SS22): port/connectivity
  completeness, full reset-to-every-state sequencing, autonomous operation
  without continuous host participation, simultaneous-evidence
  preservation, per-domain reset scope isolation, adapter-error
  propagation boundaries, SRS timing bounds at exact boundary values,
  worst-case traffic/backpressure, finite-resource boundary behavior,
  observational/test-mode operation blocking, pad population fidelity,
  and FPGA/ASIC behavioral equivalence.
- **`VP-TEST-001` through `VP-TEST-012`** (SS20): production-test
  authorization timing, qualified test-active exclusivity, command
  execution ordering, CAPTURE/SHIFT/SAFE_LOOPBACK argument legality,
  atomic diagnostic capture, loopback endpoint safety, injection
  authorization boundaries, reset/deauthorization determinism, and the
  hard requirement that no production-test path ever activates a safety
  output or bypasses protected configuration/routing authorization/
  register access/clock-reset control (`VP-TEST-010`).

Anything these reveal as a genuine `-002` gap or ambiguity — not a coding
error — goes in `OPEN_ISSUES.md` for `spec-verifier`, not silently resolved
here.
