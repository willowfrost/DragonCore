`timescale 1ns/1ps
module rtl024_skeleton_tb;
  logic core_clk_i = 0, por_n_i;
  logic spi_sclk_i=0, spi_cs_n_i=1, spi_mosi_i=0, spi_miso_o, spi_miso_oe_o;
  logic host_irq_n_o;
  logic [7:0] gpio_i=0, gpio_o, gpio_oe_o;
  logic arinc_rx_i=0, arinc_rx_adapter_error_i=0, arinc_tx_adapter_error_i=0;
  logic [1:0] arinc_tx_ctrl_o;
  logic can_rx_i=0, can_tx_o, can_transceiver_error_i=0;
  logic uart_rx_i=0, uart_tx_o;
  logic rotor_i=0, engine_i=0;
  logic [1:0] pulse_i=0;
  logic [7:0] health_i=0;
  logic [3:0] safety_out_o;
  logic [3:0] user_i=0, user_o, user_oe_o;
  logic test_enable_i=0, test_clock_i=0, test_data_i=0, test_data_o, test_data_oe_o;

  always #10 core_clk_i = ~core_clk_i;

  dfc_rtl024 dut (.*);

  int errors=0, checks=0;
  task automatic check(string what, logic got, logic exp);
    checks++;
    if (got !== exp) begin errors++; $display("FAIL: %s got=%b exp=%b", what, got, exp); end
    else $display("PASS: %s", what);
  endtask

  initial begin
    por_n_i = 0;
    repeat(2) @(posedge core_clk_i);
    check("core_rst_n low immediately after POR assert", dut.core_rst_n, 1'b0);

    por_n_i = 1;
    // should stay in reset for the first 3 edges after por_n_i release, then release on the 4th
    @(posedge core_clk_i); check("rst_n still low, edge 1", dut.core_rst_n, 1'b0);
    @(posedge core_clk_i); check("rst_n still low, edge 2", dut.core_rst_n, 1'b0);
    @(posedge core_clk_i); check("rst_n still low, edge 3", dut.core_rst_n, 1'b0);
    @(posedge core_clk_i); #1; check("rst_n released after 4 valid edges", dut.core_rst_n, 1'b1);

    check("host_irq_n_o safe-high with no sources", host_irq_n_o, 1'b1);
    check("can_tx_o recessive high stub", can_tx_o, 1'b1);
    check("uart_tx_o idle high stub", uart_tx_o, 1'b1);
    check("safety_out_o inactive stub", |safety_out_o, 1'b0);
    check("spi_miso_oe_o disabled while CS_N inactive", spi_miso_oe_o, 1'b0);

    $display("rtl024_skeleton_tb: %0d checks, %0d errors", checks, errors);
    if (errors) begin
      $display("TEST FAILED");
      $finish(1);
    end else begin
      $display("TEST PASSED");
      $finish(0);
    end
  end
endmodule
