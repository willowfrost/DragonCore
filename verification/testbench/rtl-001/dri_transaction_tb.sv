// dri_transaction_tb.sv -- end-to-end DRI protocol test for dfc_rtl001.
// Drives real DRI transactions (not internal peeks) and checks the
// externally-observable protocol/response contract.

`timescale 1ns/1ps

module dri_transaction_tb;

  import dfc_constants_pkg::*;
  import dfc_registers_pkg::*;

  logic core_clk_i = 0;
  logic core_rst_n_i;
  logic dri_req_valid_i, dri_req_ready_o, dri_req_write_i;
  logic [31:0] dri_req_addr_i, dri_req_wdata_i;
  logic [3:0]  dri_req_wstrb_i;
  logic dri_rsp_valid_o, dri_rsp_ready_i;
  logic [31:0] dri_rsp_rdata_o;
  logic [2:0]  dri_rsp_code_o;

  // Same isolation choice for RTL-001's own real timestamp_i/
  // operating_state_i/observational_mode_i broadcast inputs, added this
  // session (OPEN_ISSUES.md item 142): this testbench exercises the DRI
  // protocol in isolation and has no RTL-002/RTL-004 to drive these for
  // real, so they're tied to a disclosed stub (all-zero).
  logic [63:0] timestamp_i = '0;
  logic [dfc_types_pkg::DFC_OPERATING_STATE_WIDTH-1:0] operating_state_i = '0;
  logic        observational_mode_i = '0;

  // This testbench exercises RTL-001's DRI protocol in isolation and does
  // not model RTL-002 at all -- rtl002_status_i is tied to a disclosed
  // stub ('0) and rtl002_control_o is left unread. This is fine for this
  // testbench's actual scope (DRI protocol correctness), but means it
  // cannot observe whether SYS_CONTROL/SUBSYS_ENABLE/RESET_CONTROL writes
  // actually reach RTL-002 -- that's rtl002_integration_tb.sv's job.
  logic [dfc_types_pkg::DFC_RTL002_CONTROL_WIDTH-1:0] rtl002_control_o;
  logic [dfc_types_pkg::DFC_RTL002_STATUS_WIDTH-1:0]  rtl002_status_i = '0;
  // Same isolation choice for RTL-003, added this session: this testbench
  // does not model RTL-003 either -- rtl003_status_i is tied to a
  // disclosed stub ('0) and rtl003_control_o is left unread. A `.*`
  // wildcard port connection errors on an unmatched port under Icarus
  // (confirmed project-wide finding, not assumed) -- these declarations
  // exist so `dut (.*, ...)` below still elaborates now that dfc_rtl001.sv
  // has these two new real ports.
  logic [dfc_types_pkg::DFC_RTL003_CONTROL_WIDTH-1:0] rtl003_control_o;
  logic [dfc_types_pkg::DFC_RTL003_STATUS_WIDTH-1:0]  rtl003_status_i = '0;
  // Same isolation choice for RTL-004, added this session: this testbench
  // does not model RTL-004 either -- rtl004_status_i is tied to a
  // disclosed stub ('0) and rtl004_control_o is left unread.
  logic [dfc_types_pkg::DFC_RTL004_CONTROL_WIDTH-1:0] rtl004_control_o;
  logic [dfc_types_pkg::DFC_RTL004_STATUS_WIDTH-1:0]  rtl004_status_i = '0;
  // Same isolation choice for RTL-005, added during RTL-005's own
  // integration session: this testbench does not model RTL-005 either --
  // rtl005_status_i is tied to a disclosed stub ('0) and rtl005_control_o
  // is left unread.
  logic [dfc_types_pkg::DFC_RTL005_CONTROL_WIDTH-1:0] rtl005_control_o;
  logic [dfc_types_pkg::DFC_RTL005_STATUS_WIDTH-1:0]  rtl005_status_i = '0;
  // Same isolation choice for RTL-006, added during RTL-006's own
  // integration session: this testbench does not model RTL-006 either --
  // rtl006_status_i is tied to a disclosed stub ('0) and rtl006_control_o
  // is left unread.
  logic [dfc_types_pkg::DFC_RTL006_CONTROL_WIDTH-1:0] rtl006_control_o;
  logic [dfc_types_pkg::DFC_RTL006_STATUS_WIDTH-1:0]  rtl006_status_i = '0;
  // Same isolation choice for RTL-007, added during RTL-007's own
  // integration session: this testbench does not model RTL-007 either --
  // rtl007_status_i is tied to a disclosed stub ('0) and rtl007_control_o
  // is left unread.
  logic [dfc_types_pkg::DFC_RTL007_CONTROL_WIDTH-1:0] rtl007_control_o;
  logic [dfc_types_pkg::DFC_RTL007_STATUS_WIDTH-1:0]  rtl007_status_i = '0;
  // Same isolation choice for RTL-008, added during RTL-008's own
  // integration session: this testbench does not model RTL-008 either --
  // rtl008_status_i is tied to a disclosed stub ('0) and rtl008_control_o
  // is left unread.
  logic [dfc_types_pkg::DFC_RTL008_CONTROL_WIDTH-1:0] rtl008_control_o;
  logic [dfc_types_pkg::DFC_RTL008_STATUS_WIDTH-1:0]  rtl008_status_i = '0;
  // Same isolation choice for RTL-009, added during RTL-009's own
  // integration session: this testbench does not model RTL-009 either --
  // rtl009_status_i is tied to a disclosed stub ('0) and rtl009_control_o
  // is left unread.
  logic [dfc_types_pkg::DFC_RTL009_CONTROL_WIDTH-1:0] rtl009_control_o;
  logic [dfc_types_pkg::DFC_RTL009_STATUS_WIDTH-1:0]  rtl009_status_i = '0;
  // Same isolation choice for RTL-010, added during RTL-010's own
  // integration session: this testbench does not model RTL-010 either --
  // rtl010_status_i is tied to a disclosed stub ('0) and rtl010_control_o
  // is left unread.
  logic [dfc_types_pkg::DFC_RTL010_CONTROL_WIDTH-1:0] rtl010_control_o;
  logic [dfc_types_pkg::DFC_RTL010_STATUS_WIDTH-1:0]  rtl010_status_i = '0;
  // Same isolation choice for RTL-011, added during RTL-011's own
  // integration session: this testbench does not model RTL-011 either --
  // rtl011_status_i is tied to a disclosed stub ('0) and rtl011_control_o
  // is left unread.
  logic [dfc_types_pkg::DFC_RTL011_CONTROL_WIDTH-1:0] rtl011_control_o;
  logic [dfc_types_pkg::DFC_RTL011_STATUS_WIDTH-1:0]  rtl011_status_i = '0;
  // Same isolation choice for RTL-012, added during RTL-012's own
  // integration session: this testbench does not model RTL-012 either --
  // rtl012_status_i is tied to a disclosed stub ('0) and rtl012_control_o
  // is left unread.
  logic [dfc_types_pkg::DFC_RTL012_CONTROL_WIDTH-1:0] rtl012_control_o;
  logic [dfc_types_pkg::DFC_RTL012_STATUS_WIDTH-1:0]  rtl012_status_i = '0;
  // Same isolation choice for RTL-013, added during RTL-013's own
  // integration session: this testbench does not model RTL-013 either --
  // rtl013_status_i is tied to a disclosed stub ('0) and rtl013_control_o
  // is left unread.
  logic [dfc_types_pkg::DFC_RTL013_CONTROL_WIDTH-1:0] rtl013_control_o;
  logic [dfc_types_pkg::DFC_RTL013_STATUS_WIDTH-1:0]  rtl013_status_i = '0;
  // Same isolation choice for RTL-014 (added during RTL-014's own
  // integration session): disclosed stub, control left unread.
  logic [dfc_types_pkg::DFC_RTL014_CONTROL_WIDTH-1:0] rtl014_control_o;
  logic [dfc_types_pkg::DFC_RTL014_STATUS_WIDTH-1:0]  rtl014_status_i = '0;
  // Same isolation choice for RTL-015 (added during RTL-015's own
  // integration session): disclosed stub, control left unread.
  logic [dfc_types_pkg::DFC_RTL015_CONTROL_WIDTH-1:0] rtl015_control_o;
  logic [dfc_types_pkg::DFC_RTL015_STATUS_WIDTH-1:0]  rtl015_status_i = '0;
  logic [dfc_types_pkg::DFC_RTL016_CONTROL_WIDTH-1:0] rtl016_control_o;
  logic [dfc_types_pkg::DFC_RTL016_STATUS_WIDTH-1:0]  rtl016_status_i = '0;
  logic [dfc_types_pkg::DFC_RTL017_CONTROL_WIDTH-1:0] rtl017_control_o;
  logic [dfc_types_pkg::DFC_RTL017_STATUS_WIDTH-1:0]  rtl017_status_i = '0;
  logic [dfc_types_pkg::DFC_RTL018_CONTROL_WIDTH-1:0] rtl018_control_o;
  logic [dfc_types_pkg::DFC_RTL018_STATUS_WIDTH-1:0]  rtl018_status_i = '0;
  logic [dfc_types_pkg::DFC_RTL019_CONTROL_WIDTH-1:0] rtl019_control_o;
  logic [dfc_types_pkg::DFC_RTL019_STATUS_WIDTH-1:0]  rtl019_status_i = '0;
  logic [dfc_types_pkg::DFC_RTL020_CONTROL_WIDTH-1:0] rtl020_control_o;
  logic [dfc_types_pkg::DFC_RTL020_STATUS_WIDTH-1:0]  rtl020_status_i = '0;
  logic [dfc_types_pkg::DFC_RTL024_ARINC_RX_ADAPTER_CONTROL_WIDTH-1:0] rtl024arxadapter_control_o;
  logic [dfc_types_pkg::DFC_RTL024_ARINC_RX_ADAPTER_STATUS_WIDTH-1:0]  rtl024arxadapter_status_i = '0;
  // Same isolation choice for the shared-buffer service, added this
  // session: this testbench does not model it either -- all six status
  // inputs are tied to a disclosed stub ('0), same pattern as every other
  // not-modeled module above.
  logic [31:0] buffer_status_status_i = '0;
  logic [31:0] buffer_client_error_count_0_1_status_i = '0;
  logic [31:0] buffer_client_error_count_2_3_status_i = '0;
  logic [31:0] buffer_client_error_count_4_5_status_i = '0;
  logic [31:0] buffer_client_error_count_6_status_i = '0;
  logic [31:0] buffer_internal_error_count_status_i = '0;
  // RTL-001's own new real status_o -- unused by this testbench (which
  // exercises DRI protocol correctness, not RTL-001's own readiness).
  logic [dfc_types_pkg::DFC_RTL001_STATUS_WIDTH-1:0] status_o;

  always #10 core_clk_i = ~core_clk_i;

  dfc_rtl001 dut (.*, .dbg_regbank_write_en_o());

  int errors = 0, checks = 0;
  task automatic check(string what, logic [31:0] got, logic [31:0] expected);
    checks++;
    if (got !== expected) begin
      errors++;
      $display("FAIL: %s -- got 0x%08h, expected 0x%08h", what, got, expected);
    end else $display("PASS: %s -- 0x%08h", what, got);
  endtask
  task automatic check3(string what, logic [2:0] got, logic [2:0] expected);
    checks++;
    if (got !== expected) begin
      errors++;
      $display("FAIL: %s -- got %03b, expected %03b", what, got, expected);
    end else $display("PASS: %s -- %03b", what, got);
  endtask

  // One full DRI read or write transaction, waiting properly for both
  // request acceptance and response acceptance -- no clocking races.
  task automatic dri_txn(input logic write, input logic [31:0] addr,
                         input logic [31:0] wdata, input logic [3:0] wstrb,
                         output logic [31:0] rdata, output logic [2:0] code);
    dri_req_valid_i = 1'b1;
    dri_req_write_i = write;
    dri_req_addr_i  = addr;
    dri_req_wdata_i = wdata;
    dri_req_wstrb_i = wstrb;
    // wait for acceptance (valid && ready) at a clock edge
    do @(posedge core_clk_i); while (!dri_req_ready_o);
    #1;  // settle past the edge before dropping valid -- avoid the same
         // clocking race documented in regbank_smoke_tb.sv
    dri_req_valid_i = 1'b0;
    dri_rsp_ready_i = 1'b1;
    // wait for response valid
    do @(posedge core_clk_i); while (!dri_rsp_valid_o);
    #1;
    rdata = dri_rsp_rdata_o;
    code  = dri_rsp_code_o;
    dri_rsp_ready_i = 1'b0;
  endtask

  logic [31:0] rdata;
  logic [2:0] code;

  initial begin
    dri_req_valid_i = 0; dri_req_write_i = 0; dri_req_addr_i = 0;
    dri_req_wdata_i = 0; dri_req_wstrb_i = 4'b1111; dri_rsp_ready_i = 0;

    core_rst_n_i = 0;
    repeat (4) @(posedge core_clk_i);
    core_rst_n_i = 1;
    @(posedge core_clk_i);

    // ---- Read a CONST register ----
    dri_txn(0, DFC_ADDR_DFC_DEVICE_ID, '0, 4'b1111, rdata, code);
    check("read DFC_DEVICE_ID", rdata, 32'h4446_4331);
    check3("read DFC_DEVICE_ID code OK", code, 3'b000);

    // ---- Write+readback an unprotected internal_reg register ----
    // SYS_CONTROL is deliberately NOT used here: REG-002 lists it as
    // "Yes for bits 0-3" (qualified protection), and reggen.py v2
    // conservatively flags any qualified protection as fully protected
    // (see reggen.py's file header) -- so SYS_CONTROL correctly returns
    // PROTECTED_ERROR without auth. CONDITION_MASK_SELECT has no
    // protection requirement at all and exercises the same write path.
    dri_txn(1, DFC_ADDR_CONDITION_MASK_SELECT, 32'hCAFE_0001, 4'b1111, rdata, code);
    check3("write CONDITION_MASK_SELECT code OK", code, 3'b000);
    dri_txn(0, DFC_ADDR_CONDITION_MASK_SELECT, '0, 4'b1111, rdata, code);
    check("readback CONDITION_MASK_SELECT", rdata, 32'hCAFE_0001);

    // ---- Decode error on an unmapped, but aligned, address ----
    // (0x9999 is misaligned and would trip the alignment check first,
    // which is a different -- also real -- code path; 0x9998 is aligned
    // and genuinely unmapped.)
    dri_txn(0, 32'h0000_9998, '0, 4'b1111, rdata, code);
    check3("unmapped aligned address -> DECODE_ERROR", code, 3'b001);

    // ---- Access error: write to a CONST register ----
    dri_txn(1, DFC_ADDR_DFC_DEVICE_ID, 32'hDEAD_0000, 4'b1111, rdata, code);
    check3("write to CONST -> ACCESS_ERROR", code, 3'b010);

    // ---- Access error: partial write strobe ----
    dri_txn(1, DFC_ADDR_SYS_CONTROL, 32'h0000_0001, 4'b0011, rdata, code);
    check3("partial wstrb -> ACCESS_ERROR", code, 3'b010);

    // ---- Protection: write to a protected register without auth ----
    dri_txn(1, DFC_ADDR_RESET_CONTROL, 32'h0000_0001, 4'b1111, rdata, code);
    check3("protected write w/o auth -> PROTECTED_ERROR", code, 3'b011);

    // ---- Protection: correct key sequence then protected write succeeds ----
    dri_txn(1, DFC_ADDR_PROTECT_KEY, DFC_PROTECT_KEY1, 4'b1111, rdata, code);
    check3("PROTECT_KEY key1 write OK", code, 3'b000);
    dri_txn(1, DFC_ADDR_PROTECT_KEY, DFC_PROTECT_KEY2, 4'b1111, rdata, code);
    check3("PROTECT_KEY key2 write OK", code, 3'b000);
    dri_txn(1, DFC_ADDR_RESET_CONTROL, 32'h0000_0001, 4'b1111, rdata, code);
    check3("protected write with valid auth -> OK", code, 3'b000);

    // ---- Authorization consumed: a second protected write fails ----
    dri_txn(1, DFC_ADDR_RESET_CONTROL, 32'h0000_0002, 4'b1111, rdata, code);
    check3("second protected write, auth consumed -> PROTECTED_ERROR", code, 3'b011);

    $display("");
    $display("dri_transaction_tb: %0d checks, %0d failures", checks, errors);
    if (errors != 0) begin
      $display("TEST FAILED");
      $finish(1);
    end else begin
      $display("TEST PASSED");
      $finish(0);
    end
  end

endmodule : dri_transaction_tb
