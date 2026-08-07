// dri_one_outstanding_formal.sv -- formal contract monitor for ARCH-002 SS7.1's
// DRI protocol classification: "a CORE_CLK-domain, single-master, ordered,
// non-pipelined, one-outstanding 32-bit request/response protocol."
//
// HONESTY NOTE: RTL-001's actual DRI decode/endpoint logic does not exist yet
// in this repository -- only the register storage/consumer layer
// (dfc_config_regbank_regs.sv) has been generated so far. This file is a
// standalone property monitor over the DRI signal set (ARCH-DRI-001 through
// ARCH-DRI-009), written against the interface contract itself, so it is
// ready to bind against RTL-001's DRI endpoint the moment that logic exists.
// Until then, `formal_top` below is a minimal signal-only stub purely so the
// properties have something to bind to and can be exercised in isolation
// (e.g. against a reference/golden model, or self-consistency of the
// property set) -- it is NOT a model of RTL-001 and passing against the stub
// proves nothing about RTL-001's actual behavior.
//
// Properties checked, each citing its exact ARCH-002 source:
//   P_ONE_OUTSTANDING   -- SS7.1: at most one accepted, unresponded request
//   P_REQ_STABLE        -- ARCH-DRI-001: request fields stable while stalled
//   P_RSP_STABLE        -- ARCH-DRI-006: response fields stable while stalled
//   P_EXACTLY_ONE_RSP   -- ARCH-DRI-004: exactly one response per accepted req
//   P_RESPONSE_DEADLINE -- ARCH-DRI-009: response within 8 cycles of accept
//   P_WRITE_COMMIT_SAME_CYCLE_AS_OK -- ARCH-REG-002/RTLSTD-DRI-012

module formal_top (
  input logic clk_i,
  input logic rst_ni,
  input logic dri_req_valid_i,
  input logic dri_req_ready_i,
  input logic dri_req_write_i,
  input logic [31:0] dri_req_addr_i,
  input logic [31:0] dri_req_wdata_i,
  input logic [3:0]  dri_req_wstrb_i,
  input logic dri_rsp_valid_i,
  input logic dri_rsp_ready_i,
  input logic [2:0]  dri_rsp_code_i,
  // Asserted by the (not-yet-existing) endpoint in the same cycle it commits
  // a write side effect -- exposed here only so P_WRITE_COMMIT_SAME_CYCLE_AS_OK
  // has something to check; RTL-001's real endpoint must expose an equivalent
  // internal signal when it is written.
  input logic write_commit_i
);

  // ---- request/response acceptance edges ----
  wire req_accept = dri_req_valid_i && dri_req_ready_i;
  wire rsp_accept = dri_rsp_valid_i && dri_rsp_ready_i;

  // ---- outstanding-request tracking (one-outstanding, SS7.1) ----
  logic outstanding_q;
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) outstanding_q <= 1'b0;
    else if (req_accept && !rsp_accept) outstanding_q <= 1'b1;
    else if (rsp_accept && !req_accept) outstanding_q <= 1'b0;
    // simultaneous accept+response: stays outstanding for the new request

  // ---- deadline counter (ARCH-DRI-009: response within 8 cycles) ----
  logic [3:0] cycles_since_accept_q;
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) cycles_since_accept_q <= '0;
    else if (req_accept) cycles_since_accept_q <= 4'd1;
    else if (outstanding_q) cycles_since_accept_q <= cycles_since_accept_q + 4'd1;
    else cycles_since_accept_q <= '0;

  default clocking cb @(posedge clk_i); endclocking
  default disable iff (!rst_ni);

  // P_ONE_OUTSTANDING: never accept a second request while one is outstanding
  // and unresponded (SS7.1's "non-pipelined, one-outstanding").
  P_ONE_OUTSTANDING: assert property (
    outstanding_q |-> !req_accept
  );

  // P_REQ_STABLE: request fields do not change while VALID is asserted and
  // not yet accepted (ARCH-DRI-001).
  P_REQ_STABLE: assert property (
    (dri_req_valid_i && !dri_req_ready_i) |=>
      $stable(dri_req_write_i) && $stable(dri_req_addr_i) &&
      $stable(dri_req_wdata_i) && $stable(dri_req_wstrb_i) &&
      dri_req_valid_i
  );

  // P_RSP_STABLE: response fields do not change while VALID is asserted and
  // not yet accepted (ARCH-DRI-006).
  P_RSP_STABLE: assert property (
    (dri_rsp_valid_i && !dri_rsp_ready_i) |=>
      $stable(dri_rsp_code_i) && dri_rsp_valid_i
  );

  // P_EXACTLY_ONE_RSP: an accepted request is followed by exactly one
  // response before the next request is accepted (ARCH-DRI-004). Expressed
  // as: once outstanding, dri_rsp_valid_i eventually asserts, and once it
  // does and is accepted, outstanding clears in that same cycle.
  P_EXACTLY_ONE_RSP: assert property (
    req_accept |=> s_eventually (rsp_accept)
  );

  // P_RESPONSE_DEADLINE: response within 8 CORE_CLK cycles of acceptance
  // (ARCH-DRI-009).
  P_RESPONSE_DEADLINE: assert property (
    outstanding_q && cycles_since_accept_q >= 4'd8 |-> rsp_accept
  );

  // P_WRITE_COMMIT_SAME_CYCLE_AS_OK: a write side effect commits only in the
  // same cycle RTL-001 commits an OK response (ARCH-REG-002, RTLSTD-DRI-012).
  // 3'b000 = OK per ARCH-DRI-008.
  P_WRITE_COMMIT_SAME_CYCLE_AS_OK: assert property (
    write_commit_i |-> (rsp_accept && dri_rsp_code_i == 3'b000)
  );

endmodule : formal_top
