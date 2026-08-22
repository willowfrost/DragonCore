// regbank_smoke_tb.sv -- RTL-001 register bank bring-up smoke test (v2 interface).
//
// Rewritten against reggen.py v2's real address-decode interface (addr_i /
// wdata_i / write_en_i in; rdata_o / decode_hit_o / write_illegal_o /
// protected_o out). The prior v1-interface version of this file (which used
// one dri_wr_<name>_i port per storage register and a placeholder rdata_o)
// is superseded, not extended -- v1's port set no longer exists on the
// generated module.
//
// CLOCKING-DISCIPLINE NOTE (found by simulation, not by inspection): a
// synchronous strobe input must never be deasserted in the same simulation
// delta as the clock edge that samples it -- `strobe = 1; @(posedge clk_i);
// strobe = 0;` races the DUT's own flip-flop for that same edge, and which
// one "wins" is a simulator-scheduling artifact, not something the LRM
// guarantees. The prior version of this file had exactly that pattern; it
// happened to pass under this simulator's scheduling order, which is not
// the same as being correct. Every write check below inserts a `#1` settle
// delay after the edge and before deasserting the strobe.
//
// What this file DOES check (VP-REG-001/002/003 minimum viable subset):
//   1. CONST field holds its REG-002 reset value, unwritable (write_illegal_o).
//   2. Unmapped address -> decode_hit_o low.
//   3. External-classified field mirrors status_i combinationally.
//   4. internal_reg field updates only when write_en_i is asserted with a
//      matching addr_i, via the module's own internal address decode --
//      not via a per-register port, since that no longer exists.
//   5. protected_o correctly flags a genuinely protected register.
//
// What this file does NOT check: DRI protocol framing, per-field
// reserved-bit masking within mixed registers, per-field legal-value/range
// checks (REG-ENC-001..019), staging/commit, or the W1C/capture update
// logic that reggen.py's own comments flag as not-yet-implemented. This is
// a bring-up smoke test for the storage/decode layer, not RTL-001's full
// verification suite (see docs/rtl_specs/RTL-001_RevB.md SS8).

`timescale 1ns/1ps

module regbank_smoke_tb;

  import dfc_constants_pkg::*;
  import dfc_registers_pkg::*;

  logic clk_i;
  logic rst_ni;
  logic [31:0] addr_i;
  logic [31:0] wdata_i;
  logic write_en_i;
  logic [31:0] rdata_o;
  logic decode_hit_o;
  logic write_illegal_o;
  logic protected_o;

  logic [31:0] protect_status_status_i;
  // Replaced by the aggregated real RTL-002 bus (see dfc_rtl001.sv/
  // dfc_config_regbank_regs.sv) -- sys_status_status_i, subsys_ready_
  // status_i, subsys_fault_status_i, and reset_status_status_i no longer
  // exist as individual ports.
  logic [dfc_types_pkg::DFC_RTL002_STATUS_WIDTH-1:0]  rtl002_status_i;
  logic [dfc_types_pkg::DFC_RTL002_CONTROL_WIDTH-1:0] rtl002_control_o;
  logic [31:0] rtl002_evt_overflow_status_status_i;
  // Replaced by the aggregated real RTL-003 bus this session (same
  // treatment as RTL-002 above) -- irq_raw_status_status_i, irq_pending_
  // status_i, irq_acked_status_i, irq_clear_status_i, irq_vector_status_i,
  // and rtl003_evt_overflow_status_status_i no longer exist as individual
  // ports.
  logic [dfc_types_pkg::DFC_RTL003_STATUS_WIDTH-1:0]  rtl003_status_i;
  logic [dfc_types_pkg::DFC_RTL003_CONTROL_WIDTH-1:0] rtl003_control_o;
  // Replaced by the aggregated real RTL-004 bus this session (same
  // treatment as RTL-002/RTL-003 above) -- time_status_status_i, time_raw_lo_
  // status_i, time_raw_hi_status_i, time_sync_status_status_i, and
  // rtl004_evt_overflow_status_status_i no longer exist as individual ports.
  logic [dfc_types_pkg::DFC_RTL004_STATUS_WIDTH-1:0]  rtl004_status_i;
  logic [dfc_types_pkg::DFC_RTL004_CONTROL_WIDTH-1:0] rtl004_control_o;
  // Replaced by the aggregated real RTL-005 bus this session (same
  // treatment as RTL-002/RTL-003/RTL-004 above) -- evt_status_status_i,
  // evt_count_status_i, evt_overflow_count_status_i, evt_data0-3_status_i,
  // evt_drop_source_status_i, evt_arb_status_status_i, and
  // evt_pop_error_count_status_i no longer exist as individual ports.
  logic [dfc_types_pkg::DFC_RTL005_STATUS_WIDTH-1:0]  rtl005_status_i;
  logic [dfc_types_pkg::DFC_RTL005_CONTROL_WIDTH-1:0] rtl005_control_o;
  // Replaced by the aggregated real RTL-006 bus this session (same
  // treatment as RTL-002/RTL-003/RTL-004/RTL-005 above) -- gpio_raw_in_
  // status_i, gpio_sync_in_status_i, gpio_qual_in_status_i, gpio_event_
  // status_status_i, rtl006_evt_overflow_status_status_i, and
  // gpio_status_status_i no longer exist as individual ports.
  logic [dfc_types_pkg::DFC_RTL006_STATUS_WIDTH-1:0]  rtl006_status_i;
  logic [dfc_types_pkg::DFC_RTL006_CONTROL_WIDTH-1:0] rtl006_control_o;
  // Replaced by the aggregated real RTL-007 bus this session (same
  // treatment as RTL-002 through RTL-006 above) -- rotor_status_status_i,
  // rotor_rpm_status_i, rotor_period_ticks_status_i, and
  // rtl007_evt_overflow_status_status_i no longer exist as individual
  // ports.
  logic [dfc_types_pkg::DFC_RTL007_STATUS_WIDTH-1:0]  rtl007_status_i;
  logic [dfc_types_pkg::DFC_RTL007_CONTROL_WIDTH-1:0] rtl007_control_o;
  // Replaced by the aggregated real RTL-008 bus this session (same
  // treatment as RTL-002 through RTL-007 above) -- engine_status_status_i,
  // engine_rpm_status_i, engine_period_ticks_status_i, and
  // rtl008_evt_overflow_status_status_i no longer exist as individual
  // ports.
  logic [dfc_types_pkg::DFC_RTL008_STATUS_WIDTH-1:0]  rtl008_status_i;
  logic [dfc_types_pkg::DFC_RTL008_CONTROL_WIDTH-1:0] rtl008_control_o;
  logic [31:0] host_status_status_i;
  logic [31:0] host_last_result_status_i;
  logic [31:0] host_last_address_status_i;
  logic [31:0] host_completed_count_status_i;
  logic [31:0] host_crc_error_count_status_i;
  logic [31:0] host_abort_count_status_i;
  logic [31:0] host_timeout_count_status_i;
  logic [31:0] host_access_error_count_status_i;
  logic [31:0] rtl024_evt_overflow_status_status_i;
  logic [31:0] buffer_status_status_i;
  logic [31:0] host_last_sequence_status_i;
  logic [31:0] test_status_status_i;
  logic [31:0] arx_status_status_i;
  logic [31:0] arx_queue_level_status_i;
  logic [31:0] arx_data_status_i;
  logic [31:0] arx_meta_status_i;
  logic [31:0] arx_time_lo_status_i;
  logic [31:0] arx_time_hi_status_i;
  logic [31:0] arx_error_count_status_i;
  logic [31:0] arx_overflow_count_status_i;
  logic [31:0] rtl017_evt_overflow_status_status_i;
  logic [31:0] atx_status_status_i;
  logic [31:0] atx_queue_level_status_i;
  logic [31:0] atx_error_count_status_i;
  logic [31:0] atx_underrun_count_status_i;
  logic [31:0] rtl018_evt_overflow_status_status_i;
  logic [31:0] can_status_status_i;
  logic [31:0] can_error_count_status_i;
  logic [31:0] can_rx_level_status_i;
  logic [31:0] can_rx_id_status_i;
  logic [31:0] can_rx_meta_status_i;
  logic [31:0] can_rx_data_lo_status_i;
  logic [31:0] can_rx_data_hi_status_i;
  logic [31:0] can_rx_time_lo_status_i;
  logic [31:0] can_rx_time_hi_status_i;
  logic [31:0] can_tx_level_status_i;
  logic [31:0] rtl019_evt_overflow_status_status_i;
  logic [31:0] uart_status_status_i;
  logic [31:0] uart_rx_level_status_i;
  logic [31:0] uart_rx_data_status_i;
  logic [31:0] uart_tx_level_status_i;
  logic [31:0] uart_error_count_status_i;
  logic [31:0] rtl020_evt_overflow_status_status_i;
  logic [31:0] route_status_status_i;
  logic [31:0] route_active_source_status_i;
  logic [31:0] route_active_dest_status_i;
  logic [31:0] route_active_type_mask_status_i;
  logic [31:0] route_active_filter_value_status_i;
  logic [31:0] route_active_filter_mask_status_i;
  logic [31:0] route_entry_status_status_i;
  logic [31:0] rtl021_evt_overflow_status_status_i;
  logic [31:0] pulse0_status_status_i;
  logic [31:0] pulse0_freq_q17_15_status_i;
  logic [31:0] pulse0_period_ticks_status_i;
  logic [31:0] pulse1_status_status_i;
  logic [31:0] pulse1_freq_q17_15_status_i;
  logic [31:0] pulse1_period_ticks_status_i;
  logic [31:0] rtl009_evt_overflow_status_status_i;
  logic [31:0] sensor_status_status_i;
  logic [31:0] sensor0_value_status_i;
  logic [31:0] sensor0_status_status_i;
  logic [31:0] sensor0_current_age_ms_status_i;
  logic [31:0] sensor1_value_status_i;
  logic [31:0] sensor1_status_status_i;
  logic [31:0] sensor1_current_age_ms_status_i;
  logic [31:0] rtl010_evt_overflow_status_status_i;
  logic [31:0] sensor0_meta_status_i;
  logic [31:0] sensor1_meta_status_i;
  logic [31:0] health_raw_in_status_i;
  logic [31:0] health_sync_in_status_i;
  logic [31:0] health_qual_in_status_i;
  logic [31:0] health_active_status_i;
  logic [31:0] health_sticky_status_i;
  logic [31:0] rtl011_evt_overflow_status_status_i;
  logic [31:0] wdog_status_status_i;
  logic [31:0] wdog_elapsed_us_status_i;
  logic [31:0] rtl012_evt_overflow_status_status_i;
  logic [31:0] fault_status_status_i;
  logic [31:0] fault_class_status_i;
  logic [31:0] degraded_status_status_i;
  logic [31:0] fault_active_source_status_i;
  logic [31:0] fault_latched_source_status_i;
  logic [31:0] rtl013_evt_overflow_status_status_i;
  logic [31:0] ilock_status_status_i;
  logic [31:0] ilock_active_result_status_i;
  logic [31:0] rtl014_evt_overflow_status_status_i;
  logic [31:0] llink_status_status_i;
  logic [31:0] llink_elapsed_us_status_i;
  logic [31:0] rtl015_evt_overflow_status_status_i;
  logic [31:0] safety_status_status_i;
  logic [31:0] safety_channel_status_status_i;
  logic [31:0] rtl016_evt_overflow_status_status_i;
  logic [31:0] uli_status_status_i;
  logic [31:0] uli_in_level_status_i;
  logic [31:0] uli_out_level_status_i;
  logic [31:0] uli_out_data_status_i;
  logic [31:0] uli_io_input_status_i;
  logic [31:0] rtl022_evt_overflow_status_status_i;
  logic [31:0] uroute_status_status_i;
  logic [31:0] uroute_active_source_status_i;
  logic [31:0] uroute_active_dest_status_i;
  logic [31:0] uroute_entry_status_status_i;
  logic [31:0] rtl023_evt_overflow_status_status_i;
  int errors = 0;
  int checks = 0;

  task automatic check(string what, logic [31:0] got, logic [31:0] expected);
    checks++;
    if (got !== expected) begin
      errors++;
      $display("FAIL: %s -- got 0x%08h, expected 0x%08h", what, got, expected);
    end else begin
      $display("PASS: %s -- 0x%08h", what, got);
    end
  endtask

  task automatic check_bit(string what, logic got, logic expected);
    checks++;
    if (got !== expected) begin
      errors++;
      $display("FAIL: %s -- got %b, expected %b", what, got, expected);
    end else begin
      $display("PASS: %s -- %b", what, got);
    end
  endtask

  // Module renamed to match its filename this session -- see
  // dfc_rtl001.sv's own instantiation comment for the full account.
  dfc_config_regbank_regs dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .addr_i(addr_i),
    .wdata_i(wdata_i),
    .write_en_i(write_en_i),
    .rdata_o(rdata_o),
    .decode_hit_o(decode_hit_o),
    .write_illegal_o(write_illegal_o),
    .protected_o(protected_o),
    .rtl002_status_i(rtl002_status_i),
    .rtl002_control_o(rtl002_control_o),
    .protect_status_status_i(protect_status_status_i),
    .rtl002_evt_overflow_status_status_i(rtl002_evt_overflow_status_status_i),
    .rtl003_status_i(rtl003_status_i),
    .rtl003_control_o(rtl003_control_o),
    .rtl004_status_i(rtl004_status_i),
    .rtl004_control_o(rtl004_control_o),
    .rtl005_status_i(rtl005_status_i),
    .rtl005_control_o(rtl005_control_o),
    .rtl006_status_i(rtl006_status_i),
    .rtl006_control_o(rtl006_control_o),
    .host_status_status_i(host_status_status_i),
    .host_last_result_status_i(host_last_result_status_i),
    .host_last_address_status_i(host_last_address_status_i),
    .host_completed_count_status_i(host_completed_count_status_i),
    .host_crc_error_count_status_i(host_crc_error_count_status_i),
    .host_abort_count_status_i(host_abort_count_status_i),
    .host_timeout_count_status_i(host_timeout_count_status_i),
    .host_access_error_count_status_i(host_access_error_count_status_i),
    .rtl024_evt_overflow_status_status_i(rtl024_evt_overflow_status_status_i),
    .buffer_status_status_i(buffer_status_status_i),
    .host_last_sequence_status_i(host_last_sequence_status_i),
    .test_status_status_i(test_status_status_i),
    .arx_status_status_i(arx_status_status_i),
    .arx_queue_level_status_i(arx_queue_level_status_i),
    .arx_data_status_i(arx_data_status_i),
    .arx_meta_status_i(arx_meta_status_i),
    .arx_time_lo_status_i(arx_time_lo_status_i),
    .arx_time_hi_status_i(arx_time_hi_status_i),
    .arx_error_count_status_i(arx_error_count_status_i),
    .arx_overflow_count_status_i(arx_overflow_count_status_i),
    .rtl017_evt_overflow_status_status_i(rtl017_evt_overflow_status_status_i),
    .atx_status_status_i(atx_status_status_i),
    .atx_queue_level_status_i(atx_queue_level_status_i),
    .atx_error_count_status_i(atx_error_count_status_i),
    .atx_underrun_count_status_i(atx_underrun_count_status_i),
    .rtl018_evt_overflow_status_status_i(rtl018_evt_overflow_status_status_i),
    .can_status_status_i(can_status_status_i),
    .can_error_count_status_i(can_error_count_status_i),
    .can_rx_level_status_i(can_rx_level_status_i),
    .can_rx_id_status_i(can_rx_id_status_i),
    .can_rx_meta_status_i(can_rx_meta_status_i),
    .can_rx_data_lo_status_i(can_rx_data_lo_status_i),
    .can_rx_data_hi_status_i(can_rx_data_hi_status_i),
    .can_rx_time_lo_status_i(can_rx_time_lo_status_i),
    .can_rx_time_hi_status_i(can_rx_time_hi_status_i),
    .can_tx_level_status_i(can_tx_level_status_i),
    .rtl019_evt_overflow_status_status_i(rtl019_evt_overflow_status_status_i),
    .uart_status_status_i(uart_status_status_i),
    .uart_rx_level_status_i(uart_rx_level_status_i),
    .uart_rx_data_status_i(uart_rx_data_status_i),
    .uart_tx_level_status_i(uart_tx_level_status_i),
    .uart_error_count_status_i(uart_error_count_status_i),
    .rtl020_evt_overflow_status_status_i(rtl020_evt_overflow_status_status_i),
    .route_status_status_i(route_status_status_i),
    .route_active_source_status_i(route_active_source_status_i),
    .route_active_dest_status_i(route_active_dest_status_i),
    .route_active_type_mask_status_i(route_active_type_mask_status_i),
    .route_active_filter_value_status_i(route_active_filter_value_status_i),
    .route_active_filter_mask_status_i(route_active_filter_mask_status_i),
    .route_entry_status_status_i(route_entry_status_status_i),
    .rtl021_evt_overflow_status_status_i(rtl021_evt_overflow_status_status_i),
    .rtl007_status_i(rtl007_status_i),
    .rtl007_control_o(rtl007_control_o),
    .rtl008_status_i(rtl008_status_i),
    .rtl008_control_o(rtl008_control_o),
    .pulse0_status_status_i(pulse0_status_status_i),
    .pulse0_freq_q17_15_status_i(pulse0_freq_q17_15_status_i),
    .pulse0_period_ticks_status_i(pulse0_period_ticks_status_i),
    .pulse1_status_status_i(pulse1_status_status_i),
    .pulse1_freq_q17_15_status_i(pulse1_freq_q17_15_status_i),
    .pulse1_period_ticks_status_i(pulse1_period_ticks_status_i),
    .rtl009_evt_overflow_status_status_i(rtl009_evt_overflow_status_status_i),
    .sensor_status_status_i(sensor_status_status_i),
    .sensor0_value_status_i(sensor0_value_status_i),
    .sensor0_status_status_i(sensor0_status_status_i),
    .sensor0_current_age_ms_status_i(sensor0_current_age_ms_status_i),
    .sensor1_value_status_i(sensor1_value_status_i),
    .sensor1_status_status_i(sensor1_status_status_i),
    .sensor1_current_age_ms_status_i(sensor1_current_age_ms_status_i),
    .rtl010_evt_overflow_status_status_i(rtl010_evt_overflow_status_status_i),
    .sensor0_meta_status_i(sensor0_meta_status_i),
    .sensor1_meta_status_i(sensor1_meta_status_i),
    .health_raw_in_status_i(health_raw_in_status_i),
    .health_sync_in_status_i(health_sync_in_status_i),
    .health_qual_in_status_i(health_qual_in_status_i),
    .health_active_status_i(health_active_status_i),
    .health_sticky_status_i(health_sticky_status_i),
    .rtl011_evt_overflow_status_status_i(rtl011_evt_overflow_status_status_i),
    .wdog_status_status_i(wdog_status_status_i),
    .wdog_elapsed_us_status_i(wdog_elapsed_us_status_i),
    .rtl012_evt_overflow_status_status_i(rtl012_evt_overflow_status_status_i),
    .fault_status_status_i(fault_status_status_i),
    .fault_class_status_i(fault_class_status_i),
    .degraded_status_status_i(degraded_status_status_i),
    .fault_active_source_status_i(fault_active_source_status_i),
    .fault_latched_source_status_i(fault_latched_source_status_i),
    .rtl013_evt_overflow_status_status_i(rtl013_evt_overflow_status_status_i),
    .ilock_status_status_i(ilock_status_status_i),
    .ilock_active_result_status_i(ilock_active_result_status_i),
    .rtl014_evt_overflow_status_status_i(rtl014_evt_overflow_status_status_i),
    .llink_status_status_i(llink_status_status_i),
    .llink_elapsed_us_status_i(llink_elapsed_us_status_i),
    .rtl015_evt_overflow_status_status_i(rtl015_evt_overflow_status_status_i),
    .safety_status_status_i(safety_status_status_i),
    .safety_channel_status_status_i(safety_channel_status_status_i),
    .rtl016_evt_overflow_status_status_i(rtl016_evt_overflow_status_status_i),
    .uli_status_status_i(uli_status_status_i),
    .uli_in_level_status_i(uli_in_level_status_i),
    .uli_out_level_status_i(uli_out_level_status_i),
    .uli_out_data_status_i(uli_out_data_status_i),
    .uli_io_input_status_i(uli_io_input_status_i),
    .rtl022_evt_overflow_status_status_i(rtl022_evt_overflow_status_status_i),
    .uroute_status_status_i(uroute_status_status_i),
    .uroute_active_source_status_i(uroute_active_source_status_i),
    .uroute_active_dest_status_i(uroute_active_dest_status_i),
    .uroute_entry_status_status_i(uroute_entry_status_status_i),
    .rtl023_evt_overflow_status_status_i(rtl023_evt_overflow_status_status_i)
  );

  // Clock generation: 50 MHz nominal (ARCH-CLK-001), free-running.
  initial clk_i = 0;
  always #10 clk_i = ~clk_i;

  initial begin
    protect_status_status_i = 32'h0;
    rtl002_evt_overflow_status_status_i = 32'h0;
    rtl003_status_i = '0;
    rtl004_status_i = '0;
    rtl005_status_i = '0;
    rtl006_status_i = '0;
    host_status_status_i = 32'h0;
    host_last_result_status_i = 32'h0;
    host_last_address_status_i = 32'h0;
    host_completed_count_status_i = 32'h0;
    host_crc_error_count_status_i = 32'h0;
    host_abort_count_status_i = 32'h0;
    host_timeout_count_status_i = 32'h0;
    host_access_error_count_status_i = 32'h0;
    rtl024_evt_overflow_status_status_i = 32'h0;
    buffer_status_status_i = 32'h0;
    host_last_sequence_status_i = 32'h0;
    test_status_status_i = 32'h0;
    arx_status_status_i = 32'h0;
    arx_queue_level_status_i = 32'h0;
    arx_data_status_i = 32'h0;
    arx_meta_status_i = 32'h0;
    arx_time_lo_status_i = 32'h0;
    arx_time_hi_status_i = 32'h0;
    arx_error_count_status_i = 32'h0;
    arx_overflow_count_status_i = 32'h0;
    rtl017_evt_overflow_status_status_i = 32'h0;
    atx_status_status_i = 32'h0;
    atx_queue_level_status_i = 32'h0;
    atx_error_count_status_i = 32'h0;
    atx_underrun_count_status_i = 32'h0;
    rtl018_evt_overflow_status_status_i = 32'h0;
    can_status_status_i = 32'h0;
    can_error_count_status_i = 32'h0;
    can_rx_level_status_i = 32'h0;
    can_rx_id_status_i = 32'h0;
    can_rx_meta_status_i = 32'h0;
    can_rx_data_lo_status_i = 32'h0;
    can_rx_data_hi_status_i = 32'h0;
    can_rx_time_lo_status_i = 32'h0;
    can_rx_time_hi_status_i = 32'h0;
    can_tx_level_status_i = 32'h0;
    rtl019_evt_overflow_status_status_i = 32'h0;
    uart_status_status_i = 32'h0;
    uart_rx_level_status_i = 32'h0;
    uart_rx_data_status_i = 32'h0;
    uart_tx_level_status_i = 32'h0;
    uart_error_count_status_i = 32'h0;
    rtl020_evt_overflow_status_status_i = 32'h0;
    route_status_status_i = 32'h0;
    route_active_source_status_i = 32'h0;
    route_active_dest_status_i = 32'h0;
    route_active_type_mask_status_i = 32'h0;
    route_active_filter_value_status_i = 32'h0;
    route_active_filter_mask_status_i = 32'h0;
    route_entry_status_status_i = 32'h0;
    rtl021_evt_overflow_status_status_i = 32'h0;
    rtl007_status_i = '0;
    rtl008_status_i = '0;
    pulse0_status_status_i = 32'h0;
    pulse0_freq_q17_15_status_i = 32'h0;
    pulse0_period_ticks_status_i = 32'h0;
    pulse1_status_status_i = 32'h0;
    pulse1_freq_q17_15_status_i = 32'h0;
    pulse1_period_ticks_status_i = 32'h0;
    rtl009_evt_overflow_status_status_i = 32'h0;
    sensor_status_status_i = 32'h0;
    sensor0_value_status_i = 32'h0;
    sensor0_status_status_i = 32'h0;
    sensor0_current_age_ms_status_i = 32'h0;
    sensor1_value_status_i = 32'h0;
    sensor1_status_status_i = 32'h0;
    sensor1_current_age_ms_status_i = 32'h0;
    rtl010_evt_overflow_status_status_i = 32'h0;
    sensor0_meta_status_i = 32'h0;
    sensor1_meta_status_i = 32'h0;
    health_raw_in_status_i = 32'h0;
    health_sync_in_status_i = 32'h0;
    health_qual_in_status_i = 32'h0;
    health_active_status_i = 32'h0;
    health_sticky_status_i = 32'h0;
    rtl011_evt_overflow_status_status_i = 32'h0;
    wdog_status_status_i = 32'h0;
    wdog_elapsed_us_status_i = 32'h0;
    rtl012_evt_overflow_status_status_i = 32'h0;
    fault_status_status_i = 32'h0;
    fault_class_status_i = 32'h0;
    degraded_status_status_i = 32'h0;
    fault_active_source_status_i = 32'h0;
    fault_latched_source_status_i = 32'h0;
    rtl013_evt_overflow_status_status_i = 32'h0;
    ilock_status_status_i = 32'h0;
    ilock_active_result_status_i = 32'h0;
    rtl014_evt_overflow_status_status_i = 32'h0;
    llink_status_status_i = 32'h0;
    llink_elapsed_us_status_i = 32'h0;
    rtl015_evt_overflow_status_status_i = 32'h0;
    safety_status_status_i = 32'h0;
    safety_channel_status_status_i = 32'h0;
    rtl016_evt_overflow_status_status_i = 32'h0;
    uli_status_status_i = 32'h0;
    uli_in_level_status_i = 32'h0;
    uli_out_level_status_i = 32'h0;
    uli_out_data_status_i = 32'h0;
    uli_io_input_status_i = 32'h0;
    rtl022_evt_overflow_status_status_i = 32'h0;
    uroute_status_status_i = 32'h0;
    uroute_active_source_status_i = 32'h0;
    uroute_active_dest_status_i = 32'h0;
    uroute_entry_status_status_i = 32'h0;
    rtl023_evt_overflow_status_status_i = 32'h0;
    rtl002_status_i = '0;
    addr_i = '0;
    wdata_i = '0;
    write_en_i = 1'b0;

    // ---- Reset ----
    rst_ni = 1'b0;
    repeat (4) @(posedge clk_i);
    rst_ni = 1'b1;
    @(posedge clk_i);

    // ---- Check 1: CONST field holds its REG-002 reset value, unwritable ----
    addr_i = DFC_ADDR_DFC_DEVICE_ID;
    #1;
    check("DFC_DEVICE_ID reset value", rdata_o, 32'h4446_4331);
    check_bit("DFC_DEVICE_ID decode_hit", decode_hit_o, 1'b1);
    check_bit("DFC_DEVICE_ID write_illegal (CONST)", write_illegal_o, 1'b1);

    // ---- Check 2: unmapped address -> decode_hit_o low ----
    addr_i = 32'h0000_9999;
    #1;
    check_bit("unmapped address decode_hit low", decode_hit_o, 1'b0);

    // ---- Check 3: external field mirrors status_i combinationally ----
    // Redirected from SYS_STATUS to IRQ_RAW_STATUS (RTL-002 integration),
    // then to TIME_STATUS (RTL-003 integration), then to EVT_STATUS
    // (RTL-004 integration), then to GPIO_RAW_IN (RTL-005 integration), then
    // to ROTOR_STATUS (RTL-006 integration), then to ENGINE_STATUS (RTL-007
    // integration), and now redirected a seventh time this session to
    // PULSE0_STATUS: ENGINE_STATUS's own status_i is no longer an
    // individual port either (it's now aggregated into rtl008_status_i,
    // real cross-module wiring covered by rtl008_integration_tb.sv
    // instead). PULSE0_STATUS (RTL-009, not yet real) is untouched by that
    // change and still uses the original generic per-register status_i
    // mechanism this check is actually meant to exercise.
    pulse0_status_status_i = 32'hA5A5_0018;
    addr_i = DFC_ADDR_PULSE0_STATUS;
    #1;
    check("PULSE0_STATUS mirrors status_i", rdata_o, 32'hA5A5_0018);
    check_bit("PULSE0_STATUS write_illegal (external)", write_illegal_o, 1'b1);
    pulse0_status_status_i = 32'h0000_0041;
    #1;
    check("PULSE0_STATUS tracks status_i change combinationally", rdata_o, 32'h0000_0041);

    // ---- Check 4: internal_reg updates only via addr-decoded write_en_i ----
    addr_i = DFC_ADDR_SYS_CONTROL;
    #1;
    check("SYS_CONTROL reset value", rdata_o, 32'h0000_000A);
    check_bit("SYS_CONTROL not write_illegal", write_illegal_o, 1'b0);

    wdata_i = 32'hDEAD_BEEF;
    write_en_i = 1'b0;
    @(posedge clk_i);
    #1;
    check("SYS_CONTROL unchanged when write_en_i low", rdata_o, 32'h0000_000A);

    write_en_i = 1'b1;
    @(posedge clk_i);
    #1;  // settle before deasserting -- see file header
    write_en_i = 1'b0;
    check("SYS_CONTROL updates when write_en_i high", rdata_o, 32'hDEAD_BEEF);

    // ---- Check 5: protected_o flags a genuinely protected register ----
    addr_i = DFC_ADDR_RESET_CONTROL;
    #1;
    check_bit("RESET_CONTROL protected_o high", protected_o, 1'b1);

    $display("");
    $display("regbank_smoke_tb: %0d checks, %0d failures", checks, errors);
    if (errors != 0) begin
      $display("SMOKE TEST FAILED");
      $finish(1);
    end else begin
      $display("SMOKE TEST PASSED (bring-up scope only -- see file header)");
      $finish(0);
    end
  end

endmodule : regbank_smoke_tb
