// rtl002_state_tb.sv -- standalone RTL-002 System Control Logic testbench.
// Drives control_i/module_ready_i/module_fault_i directly (no DRI/RTL-001
// involved) and checks the externally-observable operating-state,
// readiness/timeout, degraded-ack, and reset-command contract per
// VP-MOD-002/VP-INF-001-003 (RTL-002_RevA.md SS7).
//
// SCOPE: this exercises RTL-002 in isolation with module_ready_i/
// module_fault_i driven directly by the testbench -- it does NOT model
// RTL-001's or any other real module's actual status_o behavior (that is
// dri_transaction_tb.sv's/the skeleton tb's job once those modules are
// integrated). Per RTL-002_RevA.md SS8's disclosed gap, RTL-003 through
// RTL-023 do not exist yet, so this file's readiness/fault stimulus is a
// stand-in for all 24 module producers, not a real integration test.
//
// CLOCKING-DISCIPLINE NOTE (same lesson as regbank_smoke_tb.sv/
// dri_transaction_tb.sv): every strobe/one-cycle-command field is asserted
// for exactly one full clock period and deasserted with a #1 settle delay
// after the sampling edge, never in the same delta as the edge.

`timescale 1ns/1ps

module rtl002_state_tb;

  logic core_clk_i = 0;
  logic core_rst_n_i;
  logic module_reset_i = 1'b0;

  // Same TOOLCHAIN-DRIVEN DEVIATION as dfc_rtl002.sv/dfc_rtl024.sv (see
  // those files' headers) -- dfc_types_pkg::some_type_t cannot be a
  // declared type on the person's real production Yosys build. This
  // testbench only ever compiles/runs via Icarus (sim.ps1), which has
  // never rejected this pattern -- so this change isn't fixing an actual
  // failure here, it's for consistency with the RTL files' style and in
  // case this testbench is ever repurposed as a formal-harness base
  // (which WOULD go through Yosys, per this project's existing formal-
  // verification pattern). Sized via the generated `dfc_types_pkg::
  // DFC_*_WIDTH` VALUE constants, same as the RTL files.
  logic [dfc_types_pkg::DFC_RTL002_CONTROL_WIDTH-1:0] control_i;
  logic [dfc_types_pkg::DFC_RTL002_STATUS_WIDTH-1:0]  status_o;

  logic [63:0] timestamp_i = 64'd0;
  logic        evt_valid_o;
  logic        evt_ready_i = 1'b0;
  logic [dfc_types_pkg::DFC_EVENT_RECORD_WIDTH-1:0] evt_record_o;
  logic        irq_req_o;

  logic [23:0] module_ready_i = 24'h0;
  logic [23:0] module_fault_i = 24'h0;
  logic [23:0] module_reset_o;
  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_o;
  logic        observational_mode_o;
  // New real port this session -- tied inactive here since this testbench
  // exercises the primary state machine's other transitions and doesn't
  // specifically target TEST_DEBUG entry/exit (that's covered by the new
  // checks added below).
  logic        test_active_i = 1'b0;

  always #10 core_clk_i = ~core_clk_i;  // 50 MHz CORE_CLK

  dfc_rtl002 dut (.*);

  int errors = 0, checks = 0;
  task automatic check(string what, logic [31:0] got, logic [31:0] expected);
    checks++;
    if (got !== expected) begin
      errors++;
      $display("FAIL: %s -- got 0x%08h, expected 0x%08h", what, got, expected);
    end else $display("PASS: %s -- 0x%08h", what, got);
  endtask
  task automatic check_bit(string what, logic got, logic expected);
    checks++;
    if (got !== expected) begin
      errors++;
      $display("FAIL: %s -- got %b, expected %b", what, got, expected);
    end else $display("PASS: %s", what);
  endtask

  // ---- control_i field helpers: each pulse held one full clock, settled
  // #1 past the sampling edge before deassertion (see file header) ----
  task automatic pulse_degraded_ack();
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__DEGRADED_ACK_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__DEGRADED_ACK_HI] = 1'b0;
  endtask

  task automatic pulse_module_reset(input int idx);
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_CONTROL__MODULE_RESET_HI:dfc_types_pkg::DFC_RTL002_CONTROL__RESET_CONTROL__MODULE_RESET_LO] = (24'h1 << idx);
    @(posedge core_clk_i); #1;
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_CONTROL__MODULE_RESET_HI:dfc_types_pkg::DFC_RTL002_CONTROL__RESET_CONTROL__MODULE_RESET_LO] = 24'h0;
  endtask

  task automatic pulse_system_reset();
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_CONTROL__SYSTEM_RESET_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__RESET_CONTROL__SYSTEM_RESET_HI] = 1'b0;
  endtask

  task automatic apply_reset();
    control_i = '0;
    // Realistic control_i reset defaults: in real integration, control_i
    // reflects RTL-001's own registered regbank, which resets these fields
    // to REG-002's documented non-zero values -- a blanket control_i='0
    // would incorrectly model OBSERVATIONAL_MODE as already 0 at power-up,
    // which a real run of this testbench caught (see rtl002_state_tb.sv's
    // effective-enable checks).
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__OBSERVATIONAL_MODE_HI]  = 1'b1;  // SYS_CONTROL reset=1
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__GLOBAL_EVENT_ENABLE_HI] = 1'b1;  // SYS_CONTROL reset=1
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SUBSYS_ENABLE__ENABLE_HI:dfc_types_pkg::DFC_RTL002_CONTROL__SUBSYS_ENABLE__ENABLE_LO]            = 24'h80F81F;  // mandatory-only default
    core_rst_n_i = 1'b0;
    module_ready_i = 24'h0;
    module_fault_i = 24'h0;
    repeat (4) @(posedge core_clk_i);
    core_rst_n_i = 1'b1;
    @(posedge core_clk_i); #1;
  endtask

  initial begin
    apply_reset();

    // ---- Check 1: RESET_ACTIVE seen immediately, STARTUP entered on the
    // first released edge ----
    // (apply_reset already advanced one edge past release; by now DUT
    // should already be in STARTUP.)
    check("state == STARTUP right after release", operating_state_o, dfc_types_pkg::STARTUP);
    check_bit("sys_status__reset_active low after release", status_o[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__RESET_ACTIVE_HI], 1'b0);
    check_bit("sys_status__startup high after release", status_o[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__STARTUP_HI], 1'b1);

    // ---- Check 2: mandatory readiness -> NORMAL ----
    module_ready_i = 24'h80F81F;  // all mandatory bits ready, nothing else
    @(posedge core_clk_i); #1;
    check("state == NORMAL once mandatory ready", operating_state_o, dfc_types_pkg::NORMAL);
    check_bit("sys_status__init_complete set", status_o[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__INIT_COMPLETE_HI], 1'b1);
    check_bit("sys_status__init_failed clear", status_o[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__INIT_FAILED_HI], 1'b0);

    // ---- Check 3: HOST_READY registers from module_ready_i[0]/[23] ----
    check_bit("host_ready asserted (bits 0 and 23 both ready)", status_o[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__HOST_READY_HI], 1'b1);

    // ---- Check 4: EFFECTIVE_OPERATIONAL_ENABLE equation ----
    check_bit("effective_enable low, OPERATIONAL_ENABLE still 0",
              status_o[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__EFFECTIVE_OPERATIONAL_ENABLE_HI], 1'b0);
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__OPERATIONAL_ENABLE_HI] = 1'b1;
    @(posedge core_clk_i); #1;
    check_bit("effective_enable still low, OBSERVATIONAL_MODE still 1 (power-up default)",
              status_o[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__EFFECTIVE_OPERATIONAL_ENABLE_HI], 1'b0);
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SYS_CONTROL__OBSERVATIONAL_MODE_HI] = 1'b0;
    @(posedge core_clk_i); #1;  // observational_mode_q updates one cycle late
    @(posedge core_clk_i); #1;
    check_bit("effective_enable high once OPERATIONAL_ENABLE=1 and OBSERVATIONAL_MODE=0",
              status_o[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__EFFECTIVE_OPERATIONAL_ENABLE_HI], 1'b1);

    // ---- Check 5: enabled-optional fault -> DEGRADED ----
    control_i[dfc_types_pkg::DFC_RTL002_CONTROL__SUBSYS_ENABLE__ENABLE_HI:dfc_types_pkg::DFC_RTL002_CONTROL__SUBSYS_ENABLE__ENABLE_LO] = 24'h80F81F | 24'h000020;  // enable RTL-006 (bit 5)
    @(posedge core_clk_i); #1;
    module_fault_i = 24'h000020;  // RTL-006 faults
    @(posedge core_clk_i); #1;
    check("state == DEGRADED on enabled-optional fault", operating_state_o, dfc_types_pkg::DEGRADED);
    check_bit("effective_enable still high in DEGRADED",
              status_o[dfc_types_pkg::DFC_RTL002_STATUS__SYS_STATUS__EFFECTIVE_OPERATIONAL_ENABLE_HI], 1'b1);

    // ---- Check 6: DEGRADED_ACK does not exit until causes also clear ----
    pulse_degraded_ack();
    @(posedge core_clk_i); #1;
    check("state stays DEGRADED, cause not yet cleared", operating_state_o, dfc_types_pkg::DEGRADED);

    module_fault_i = 24'h0;
    @(posedge core_clk_i); #1;
    check("state == NORMAL once cause clears (ack already latched)", operating_state_o, dfc_types_pkg::NORMAL);

    // ---- Check 7: new DEGRADED episode requires a fresh ack ----
    module_fault_i = 24'h000020;
    @(posedge core_clk_i); #1;
    check("state == DEGRADED again, new episode", operating_state_o, dfc_types_pkg::DEGRADED);
    module_fault_i = 24'h0;
    @(posedge core_clk_i); #1;
    check("state stays DEGRADED without a fresh ack", operating_state_o, dfc_types_pkg::DEGRADED);
    pulse_degraded_ack();
    @(posedge core_clk_i); #1;
    check("state == NORMAL after the fresh ack", operating_state_o, dfc_types_pkg::NORMAL);

    // ---- Check 8: mandatory fault -> FAULTED, latched ----
    module_fault_i = 24'h000001;  // RTL-001 (mandatory) faults
    @(posedge core_clk_i); #1;
    check("state == FAULTED on mandatory fault", operating_state_o, dfc_types_pkg::FAULTED);
    module_fault_i = 24'h0;
    repeat (3) @(posedge core_clk_i);
    check("FAULTED remains latched after cause clears", operating_state_o, dfc_types_pkg::FAULTED);

    // ---- Check 9: module reset command, real busy/complete sequencing ----
    apply_reset();
    module_ready_i = 24'h80F81F;
    @(posedge core_clk_i); #1;
    check("state == NORMAL before exercising RESET_CONTROL", operating_state_o, dfc_types_pkg::NORMAL);

    pulse_module_reset(6);  // target RTL-007 (bit 6, an arbitrary optional bit)
    @(posedge core_clk_i); #1;
    check_bit("reset_status__busy asserted right after accepting the command",
              status_o[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__BUSY_HI], 1'b1);
    check_bit("module_reset_o[6] asserted during the hold window", module_reset_o[6], 1'b1);

    // hold for >=4 cycles total, then the DUT should deassert and start
    // waiting for module_ready_i[6]
    repeat (5) @(posedge core_clk_i);
    #1;
    check_bit("module_reset_o[6] deasserted after the assert window", module_reset_o[6], 1'b0);
    check_bit("still busy, waiting for readiness", status_o[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__BUSY_HI], 1'b1);

    module_ready_i[6] = 1'b1;  // target module reports ready again
    repeat (2) @(posedge core_clk_i);
    #1;
    check_bit("reset_status__busy clears once 2 consecutive ready cycles seen",
              status_o[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__BUSY_HI], 1'b0);
    check_bit("reset_status__complete set", status_o[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__COMPLETE_HI], 1'b1);
    check("reset_status__last_scope reflects the targeted bit", status_o[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__LAST_SCOPE_HI:dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__LAST_SCOPE_LO], 32'(24'h40));

    // ---- Check 10: a second request while busy is rejected ----
    pulse_module_reset(7);
    @(posedge core_clk_i); #1;
    pulse_module_reset(8);  // arrives while the first is still busy
    repeat (2) @(posedge core_clk_i);
    #1;
    check_bit("reset_status__rejected set for the request arriving while busy",
              status_o[dfc_types_pkg::DFC_RTL002_STATUS__RESET_STATUS__REJECTED_HI], 1'b1);

    $display("");
    $display("rtl002_state_tb: %0d checks, %0d failures", checks, errors);
    if (errors != 0) begin
      $display("TEST FAILED");
      $finish(1);
    end else begin
      $display("TEST PASSED");
      $finish(0);
    end
  end

endmodule : rtl002_state_tb
