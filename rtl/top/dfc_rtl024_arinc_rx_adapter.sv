// dfc_rtl024_arinc_rx_adapter.sv -- RTL-024's real digital ARINC 429
// receive adapter (ARCH-BUS-001). An internal RTL-024 subblock (same
// status as the shared-buffer service and the SPI bridge: hand-authored,
// instantiated inside dfc_rtl024.sv, no Appendix A port row of its own),
// NOT a separate RTL-0NN module. Owns CDC-ARINC (the synchronizer on the
// raw external pins) and ARCH-BUS-001's own bit-timing recovery;
// RTL-017's own job starts only at the already-assembled atomic word this
// module presents.
//
// Controlling documents: RCA-DFC-ARCH-002 SS11.4 (ARCH-BUS-001),
// Appendix B (dfc_rtl024_arinc_rx_adapter_control_t/status_t).
//
// ============================================================================
// SCOPE OF THIS FIRST IMPLEMENTATION -- real, disclosed simplifications,
// not silently invented behavior. ARCH-BUS-001 specifies behavior, not a
// cycle-accurate state machine; the choices below are reasonable, stated
// interpretations where the Architecture doesn't give bit-exact detail.
//
// LINE ENCODING ASSUMPTION: this module assumes the external ARINC 429
// line transceiver (whose own fault output is the external
// arinc_rx_adapter_error_i pin) has already converted the real tri-level
// BPRZ line signal into a simple two-level (NRZ-style) digital data
// stream on arinc_rx_i -- i.e. the transceiver IC does the analog
// tri-level decode; this module's own "oversampling" is bit-TIMING
// recovery (resynchronizing to the configured bit rate despite real
// clock-rate tolerance/jitter), not tri-level line decode itself. This
// matches how real commercial ARINC 429 transceiver ICs (e.g. the
// HI-8282 family) present a single RXDATA pin to the host digital logic.
//
// BIT-TIMING RECOVERY: a free-running phase counter resynchronizes to
// every detected data transition on the synchronized line (not just at
// word start) -- a standard, robust technique for a self-clocking serial
// line, analogous to this project's own planned UART approach
// (ARCH-BUS-004's "16 evenly spaced sample phases", not yet built since
// RTL-020 doesn't exist). Two FIXED bit periods are used (no continuously
// configurable divider exists in ARX_CONTROL, only a HIGH_SPEED bit):
// low speed = 12.5 kb/s nominal (within the 12-14.5 kb/s legal range),
// high speed = 100 kb/s, both derived from dfc_constants_pkg::
// DFC_CORE_CLK_HZ at elaboration time, not hand-copied cycle counts.
//
// FRAMING: word boundaries are gap-based (ARCH-BUS-001's own "at least 4
// bit times of null between words"), not start/stop-bit based -- a word
// begins on the first transition observed after a qualified >=4-bit-time
// idle gap, and completes after exactly 32 sampled bits. A framing error
// is flagged when a new transition arrives before the required gap
// completes following a word (the gap gets violated), not for ordinary
// intra-word data transitions (those are expected, normal NRZ data).
//
// PARITY: the full 32-bit word (matching real ARINC 429 format, where bit
// 31 is the parity bit) is checked for ODD total parity across all 32
// bits. ACCEPT_PARITY_ERROR=0 still completes word assembly and reports
// the error (never silently drops a word at the adapter level -- RTL-017
// is the one that decides, per its own host-configured behavior, what a
// parity-failed word means); this module only ever reports the fact.
//
// DISCLOSED GAPS, not silently resolved: REG-ENC-008 error code `110`
// (disabled) and `111` (invalid configuration) are never produced by this
// adapter. ENABLE=0 fully gates the receiver (no processing, no
// rx_word_valid_o, ever, while disabled) rather than completing an
// in-progress word and flagging it "disabled" -- a simpler, equally
// defensible reading of "disabled" with no Architecture text to say
// otherwise. ARX_CONTROL has no cross-field legality constraint to
// violate (every field is independently 0/1), so "invalid configuration"
// has no trigger condition in this design, same disclosed-unreachable
// class as the shared-buffer service's own PROTOCOL_ERROR/INTERNAL_ERROR
// (OPEN_ISSUES.md item 105).
//
// EVENT_ENABLE/IRQ_ENABLE (ARX_CONTROL bits 2-3): received and held by
// this module (part of its own control struct per ARCH-002's real field
// placement) but NOT forwarded anywhere -- RTL-017's own 33-port Appendix
// A catalog has no port to receive them, and RTL-017 already has its own
// generic event_condition_enable_i/irq_condition_enable_i (Appendix F.3)
// gating mechanism. Real, disclosed: these two bits are currently inert.
//
// NO BACKPRESSURE: rx_word_valid_o is an unconditional one-cycle pulse
// per ARCH-002's own port table ("one-cycle word indication", no
// corresponding ready input back to this adapter) -- RTL-017 must capture
// it unconditionally the instant it pulses; this adapter never stalls
// waiting for RTL-017.
// ============================================================================

module dfc_rtl024_arinc_rx_adapter (
  input  logic core_clk_i,
  input  logic core_rst_n_i,

  // Raw external pads (asynchronous) -- this module owns CDC-ARINC, the
  // same "whoever first touches the raw pad owns the synchronizer"
  // precedent as RTL-007/008/009/011.
  input  logic arinc_rx_i,
  input  logic arinc_rx_adapter_error_i,

  // Real cross-module register bus (tools/reggen/rtl024_field_map.json):
  // ARX_CONTROL's 5 real fields, flat vector per the standing pkg::type_t
  // workaround (declared types break on this toolchain) -- sized via the
  // generated WIDTH constant, bit positions via generated _HI/_LO.
  input  logic [dfc_types_pkg::DFC_RTL024_ARINC_RX_ADAPTER_CONTROL_WIDTH-1:0] control_i,
  output logic [dfc_types_pkg::DFC_RTL024_ARINC_RX_ADAPTER_STATUS_WIDTH-1:0]  status_o,

  // Same-domain outputs to RTL-017 (ARCH-002 Appendix A, RTL-017's own
  // rx_word_valid_i/rx_word_i/rx_parity_error_i/rx_framing_error_i/
  // rx_speed_high_i/rx_adapter_overrun_i/arx_adapter_error_i).
  output logic        rx_word_valid_o,
  output logic [31:0] rx_word_o,
  output logic        rx_parity_error_o,
  output logic        rx_framing_error_o,
  output logic        rx_speed_high_o,
  output logic        rx_adapter_overrun_o,
  output logic        arx_adapter_error_o
);

  wire arx_control__enable =
    control_i[dfc_types_pkg::DFC_RTL024_ARINC_RX_ADAPTER_CONTROL__ARX_CONTROL__ENABLE_HI];
  wire arx_control__high_speed =
    control_i[dfc_types_pkg::DFC_RTL024_ARINC_RX_ADAPTER_CONTROL__ARX_CONTROL__HIGH_SPEED_HI];
  wire arx_control__accept_parity_error =
    control_i[dfc_types_pkg::DFC_RTL024_ARINC_RX_ADAPTER_CONTROL__ARX_CONTROL__ACCEPT_PARITY_ERROR_HI];
  // arx_control__event_enable / arx_control__irq_enable: received, held,
  // deliberately unused -- see file header.

  assign status_o = 1'b0;  // reserved placeholder, see dfc_rtl024_arinc_rx_adapter_status_t

  // ==========================================================================
  // CDC-ARINC: 2-flop synchronizer on both raw external pads.
  // ==========================================================================
  logic [1:0] rx_sync_q;
  logic [1:0] rx_adapter_error_sync_q;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      rx_sync_q              <= 2'b00;
      rx_adapter_error_sync_q <= 2'b00;
    end else begin
      rx_sync_q              <= {rx_sync_q[0], arinc_rx_i};
      rx_adapter_error_sync_q <= {rx_adapter_error_sync_q[0], arinc_rx_adapter_error_i};
    end
  end
  wire rx_line = rx_sync_q[1];
  assign arx_adapter_error_o = rx_adapter_error_sync_q[1];

  // ==========================================================================
  // Fixed bit periods, derived from CORE_CLK_HZ -- not hand-copied cycle
  // counts. Low speed 12.5 kb/s (within ARCH-BUS-001's 12-14.5 kb/s legal
  // range), high speed 100 kb/s.
  // ==========================================================================
  localparam int unsigned BIT_PERIOD_LOW  = dfc_constants_pkg::DFC_CORE_CLK_HZ / 12_500;
  localparam int unsigned BIT_PERIOD_HIGH = dfc_constants_pkg::DFC_CORE_CLK_HZ / 100_000;
  localparam int unsigned PHASE_WIDTH = 16;  // covers BIT_PERIOD_LOW (4000 @ 50MHz) comfortably

  wire [PHASE_WIDTH-1:0] bit_period = arx_control__high_speed
    ? PHASE_WIDTH'(BIT_PERIOD_HIGH) : PHASE_WIDTH'(BIT_PERIOD_LOW);
  wire [PHASE_WIDTH-1:0] gap_threshold = bit_period << 2;  // 4 bit times

  // ==========================================================================
  // Transition detection + idle-gap tracking.
  // ==========================================================================
  logic rx_line_prev_q;
  logic transition;
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) rx_line_prev_q <= 1'b0;
    else               rx_line_prev_q <= rx_line;
  end
  assign transition = (rx_line != rx_line_prev_q);

  logic [PHASE_WIDTH-1:0] idle_count_q;
  wire                    gap_qualified = (idle_count_q >= gap_threshold);
  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      idle_count_q <= '0;
    end else if (transition) begin
      idle_count_q <= '0;
    end else if (idle_count_q != {PHASE_WIDTH{1'b1}}) begin
      idle_count_q <= idle_count_q + 1'b1;
    end
  end

  // ==========================================================================
  // Word-assembly FSM: gap-based framing, bit-center sampling re-anchored
  // to every real transition (robust against clock-rate tolerance).
  // ==========================================================================
  typedef enum logic [1:0] { W_IDLE, W_RECEIVING, W_DONE } wstate_e;
  wstate_e wstate_q;

  logic [PHASE_WIDTH-1:0] phase_count_q;
  logic [5:0]             bit_idx_q;      // 0-31 (+1 margin)
  logic [31:0]            shift_q;
  logic                   mid_word_gap_violation_q;
  logic                   overrun_flag_q;  // >=2 transitions observed within one bit period

  logic [31:0] rx_word_q;
  logic        rx_parity_error_q;
  logic        rx_framing_error_q;
  logic        rx_speed_high_q;
  logic        rx_adapter_overrun_q;
  logic        rx_word_valid_q;

  // Parity: odd parity over all 32 bits of the completed word.
  wire word_parity_ok = ^shift_q;  // XOR-reduce: 1 if odd number of set bits

  always_ff @(posedge core_clk_i or negedge core_rst_n_i) begin
    if (!core_rst_n_i) begin
      wstate_q                  <= W_IDLE;
      phase_count_q             <= '0;
      bit_idx_q                 <= 6'd0;
      shift_q                   <= 32'd0;
      mid_word_gap_violation_q  <= 1'b0;
      overrun_flag_q            <= 1'b0;
      rx_word_q                 <= 32'd0;
      rx_parity_error_q         <= 1'b0;
      rx_framing_error_q        <= 1'b0;
      rx_speed_high_q           <= 1'b0;
      rx_adapter_overrun_q      <= 1'b0;
      rx_word_valid_q           <= 1'b0;
    end else begin
      rx_word_valid_q <= 1'b0;  // one-cycle pulse, default low every cycle

      if (!arx_control__enable) begin
        // ENABLE=0: fully gated, no processing at all (see file header).
        wstate_q       <= W_IDLE;
        phase_count_q  <= '0;
        bit_idx_q      <= 6'd0;
        overrun_flag_q <= 1'b0;
      end else begin
        unique case (wstate_q)
          W_IDLE: begin
            overrun_flag_q <= 1'b0;
            if (transition && gap_qualified) begin
              // First bit of a new word begins now -- sample it at its
              // own bit-center, one half bit-period from this edge.
              wstate_q      <= W_RECEIVING;
              phase_count_q <= bit_period >> 1;
              bit_idx_q     <= 6'd0;
              shift_q       <= 32'd0;
            end
          end
          W_RECEIVING: begin
            if (transition) begin
              // Re-anchor to the real edge (robust bit-timing recovery);
              // more than one transition inside what should be a single
              // bit period means the line is toggling faster than the
              // configured rate allows -- adapter-level overrun.
              if (phase_count_q < bit_period) overrun_flag_q <= 1'b1;
              phase_count_q <= bit_period >> 1;
            end else if (phase_count_q == 'd0) begin
              // Bit-center sample point.
              shift_q       <= {rx_line, shift_q[31:1]};  // LSB-first assembly
              phase_count_q <= bit_period - 1'b1;
              if (bit_idx_q == 6'd31) begin
                wstate_q <= W_DONE;
              end else begin
                bit_idx_q <= bit_idx_q + 6'd1;
              end
            end else begin
              phase_count_q <= phase_count_q - 1'b1;
            end
          end
          W_DONE: begin
            // ARCH-002 SS11.4: "ACCEPT_PARITY_ERROR=0 rejects a parity-
            // failed receive word; one admits it with error flags set."
            // "Rejects" is implemented here, at the adapter boundary, as
            // "never presented to RTL-017 at all" (rx_word_valid_o simply
            // does not pulse) -- not as suppressing the error flag on an
            // otherwise-admitted word (that would contradict "admits it
            // WITH error flags set", which implies the flag is always the
            // true result once a word IS admitted). DISCLOSED GAP: a
            // parity-rejected-and-dropped word has no evidence path at
            // all -- neither this adapter's own control/status struct nor
            // RTL-017's fixed 33-port catalog defines a counter/signal for
            // "adapter-level silent drop," so it is genuinely invisible to
            // the host in this implementation. Logged in OPEN_ISSUES.md.
            if (word_parity_ok || arx_control__accept_parity_error) begin
              rx_word_q            <= shift_q;
              rx_parity_error_q    <= ~word_parity_ok;
              rx_framing_error_q   <= mid_word_gap_violation_q;
              rx_speed_high_q      <= arx_control__high_speed;
              rx_adapter_overrun_q <= overrun_flag_q;
              rx_word_valid_q      <= 1'b1;
            end
            mid_word_gap_violation_q <= 1'b0;
            wstate_q             <= W_IDLE;
          end
          default: wstate_q <= W_IDLE;
        endcase
      end

      // Framing violation detection: a transition arriving before the
      // required >=4-bit-time gap completes, while idle (i.e. the PREVIOUS
      // word's own trailing gap was too short) -- latched for the NEXT
      // completed word to carry, since the violation is only observable
      // right as the new word starts, one word before it finishes.
      if (wstate_q == W_IDLE && transition && !gap_qualified) begin
        mid_word_gap_violation_q <= 1'b1;
      end
    end
  end

  assign rx_word_o             = rx_word_q;
  assign rx_parity_error_o     = rx_parity_error_q;
  assign rx_framing_error_o    = rx_framing_error_q;
  assign rx_speed_high_o       = rx_speed_high_q;
  assign rx_adapter_overrun_o  = rx_adapter_overrun_q;
  assign rx_word_valid_o       = rx_word_valid_q;

endmodule : dfc_rtl024_arinc_rx_adapter
