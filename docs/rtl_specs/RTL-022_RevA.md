# RTL-022 Module Specification — Mask-Defined User Logic Island

**Revision:** A (fresh against `-002`)
**Status:** Derived artifact per `CHTR-002` SS3.3 (CHTR-DOC-006). Cites
ARCH-002, REG-002, SRS-002, VP-002. **This module's defining
characteristic is that it is deliberately inert in Revision A** — the
"correct implementation" here is one that provably does nothing
operational, not one that does something useful.

## 1. Identity and role

RTL-022 is the Dragon Core mask-defined User Logic Island: fixed
structure (not field-programmable, per `DFC-FUNC-0117`), with an
**inert Revision A functional profile** — every operational
parameter/output/message-generation path has a sole legal value of zero,
and only diagnostic input capture and two 4-word mailboxes are
functional. Owns REG-002's User Logic Island block (0x4000–0x40FF, 20
registers).

Controlling documents: `ARCH-002` SS13.1 `ARCH-ULI-001`–`005`, SS12.3
`ARCH-BUF-028` (mailbox entry layout), Appendix F.1 `ARCH-RTL022-001`,
`SRS-002` `DFC-FUNC-0117`–`0120`, VP-002 `VP-USER-001`–`004`.

## 2. Ports (11 total, per the Architecture formal port catalog)

Standard group: `core_clk_i`, `core_rst_n_i`, `module_reset_i`, `control_i`/
`status_o` (confirmed real fields: `dfc_rtl022_control_t`/`status_t`,
300/69 bits respectively — the control width is large *because* it
carries 8 always-zero parameter fields plus mailbox commands, not because
this module does much), `timestamp_i`, `operating_state_i`,
`observational_mode_i`, `test_active_i` (confirmed real port —
`RTL-024.test_active_o` → `RTL-022.test_active_i`, gating the "effective
externally effective action" per Appendix A), shared-buffer client ports
(`buf_req_o`/`buf_req_ready_i`/`buf_req_o`(payload)/`buf_rsp_valid_i`/
`buf_rsp_ready_o`/`buf_rsp_i` — client slot 5, `dfc_buffer_req_t`/32,
`dfc_buffer_rsp_t`/34), condition-enable pair (index 21). RTL-022-specific
functional ports: **4 synchronized user inputs** (captured to status
only, never influencing an output per `ARCH-ULI-005`) — confirm exact
port name against Appendix A's RTL-022 row.

## 3. Inert Revision A contract (`ARCH-ULI-001`–`005`) — the entire spec

- **`ARCH-ULI-001`**: all **8 functional parameters** have the **sole
  legal value zero**. Any nonzero parameter write or enable attempt is
  **rejected** and **sets violation evidence** — not silently ignored;
  the rejection itself is observable.
- **`ARCH-ULI-002`**: `user_o` = `4'b0000`, `user_oe` = `4'b0000`,
  `tx_msg_valid` = 0, and every operational event/interrupt/fault output
  is zero **in every state** — no exception for any mode, including test.
- **`ARCH-ULI-003`**: 4 synchronized user inputs are captured in status
  (read-only diagnostic). Input mailbox `PUSH` stores one 32-bit
  diagnostic word into its 4-word segment; output mailbox contains
  **only** words written through the diagnostic host proxy, and `POP`
  removes one. **Neither mailbox creates an operational action** — a
  mailbox write/read is pure data movement, never a trigger for anything
  functional.
- **`ARCH-ULI-004`**: `RESET_REQ` and module reset empty **both** mailbox
  pointer/valid sets, clear violation/reset evidence as defined, and
  **leave all functional parameters in RTL-001 unchanged** — resetting
  RTL-022 does not touch RTL-001's copy of the (always-zero) parameters.
- **`ARCH-ULI-005`**: route-source, route-destination, and
  message-destination inputs are observed **only as diagnostics** and
  **never** affect an output in Revision A — RTL-022 can be a message
  *destination* (per `ARCH-MSG-005`) but the received message has zero
  operational effect, purely diagnostic visibility.

Per `ARCH-RTL022-001`: implement `ARCH-ULI-001`–`005` using the generic
`ARCH-BUF-011` mailbox discipline. **Every operational output is constant
inactive.** Mailbox push/pop obey the standard full/empty rules and
complete-entry visibility (Appendix F.2's common queue table).

## 4. Registers owned (REG-002 0x4000–0x40FF, 20 registers)

8 always-zero-enforced parameter registers (`ULI_PARAM0`–`7`), enable/
event/IRQ control (rejects nonzero per `REG-ENC-017`), input/output
mailbox data/push/pop (`ULI_IN_DATA`, `ULI_IN_PUSH` confirmed at
`0x4030`, `ULI_OUT_DATA`, `ULI_OUT_LEVEL` confirmed at `0x4034`),
synchronized-input readback, status (enable/ready/mailbox-full-empty),
and `RTL022_EVT_OVERFLOW_STATUS`. Implement against
`dfc_registers_pkg.json`'s RTL-022-owned entries.

## 5. Verification obligations

- **`VP-USER-001`**–`004`: enable/parameter/mailbox behavior, **every
  nonzero functional parameter/enable/output-request rejected with
  violation evidence**, synchronized/route/message inputs observable only
  as diagnostics, and mailbox capacity/ordering/no-operational-action
  rules all hold.
- **`VP-USER-010`**: RTL-022 **remains inert** and its logical outputs
  match simulation across FPGA/ASIC realizations and every reset/test
  state — this is fundamentally a **negative-space verification
  problem**: the goal is proving the absence of any operational effect
  across every input combination, not confirming a positive behavior.
  Don't under-scope this case just because the module "does nothing" —
  proving nothing happens under adversarial/exhaustive input conditions
  is real verification work.
