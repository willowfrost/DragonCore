// dfc_mem_sp_512x36_ecp5.sv -- FPGA-specific (ECP5) body of the Centralized
// Shared-Buffer Service's single storage port. Same module name and port
// list as rtl/top/dfc_mem_sp_512x36.sv (the generic/default body); this
// file is substituted ONLY for the real ECP5 build (scripts/build_ecp5.ps1
// excludes the generic file and includes this one instead -- see that
// script's own comment at the swap point).
//
// Controlling documents: RCA-DFC-ARCH-002 ARCH-BUF-020, RCA-DFC-RTL-STD-002
// RTLSTD-MEM-013, RTLSTD-WRAP-002/008/010.
//
// PRIMITIVE CHOICE: PDPW16KD (Lattice ECP5 Pseudo-Dual-Port 16K block RAM),
// not a hand-wired DP16KD with both physical sides combined. Confirmed from
// primary sources (Yosys's own techlibs/lattice/cells_bb_ecp5.v blackbox
// declaration and Lattice's ECP5 sysMEM Memory Usage Guide, FPGA-TN-02204):
// true independent-port (True-Dual-Port) DP16KD access caps at 18 bits per
// side -- a hard pin-count limit of the physical 18Kbit EBR tile, not a
// Yosys inference quirk -- so ANY word wider than 18 bits on this chip,
// built any way, requires combining both physical sides into one logical
// port. PDPW16KD is Lattice's own directly-instantiable primitive for
// exactly that combined configuration, with a clean native 36-bit DI/DO
// bus, explicit BE[3:0] byte-enables, and separate ADW[8:0]/ADR[13:0]
// address buses -- no address-bit/byte-enable repurposing ambiguity (unlike
// hand-wiring bare DP16KD at width>=18, where Yosys's own techmap reuses
// low address bits as byte-enable bits, confirmed via
// techlibs/lattice/brams_map_16kd.v's $__PDPW16KD_ template: for a 36-bit
// configuration built from DP16KD directly, ADA0-ADA3 are repurposed as
// write-enable lanes and the real address starts at ADA4 -- exactly the
// kind of bit-repurposing PDPW16KD's own separate BE bus avoids). This is
// also the standard, vendor-recommended configuration for this exact access
// shape (one write-only side, one read-only side, matching a design that
// only ever issues one write-or-read per cycle through one arbitrated
// access point) across FPGA families generally, not a workaround forced
// onto a bad fit.
//
// ADDRESS WIRING: ADW8..ADW0 (write side) are a clean, full 9-bit bus at
// this width/depth (512 = 2^9) with no bit-stealing -- confirmed directly
// from PDPW16KD's own port declaration (ADW8..ADW0, exactly 9 bits, with
// byte-enable carried separately on BE3..BE0). ADR13..ADR0 (read side) is
// physically 14 bits wide to accommodate the narrowest 1-bit-wide/16384-
// deep configuration this same primitive also supports; at width 36 only
// the low 9 bits (ADR8..ADR0) are meaningful address, so ADR13..ADR9 are
// tied to zero below. Unlike ADW, ADR has no competing byte-enable demand
// (BE only gates writes, a universal BRAM convention -- reads always
// return the complete word), so there is no bit-repurposing question on
// the read side at all.
//
// OPEN ITEM (disclosed, not silently resolved -- see OPEN_ISSUES.md): a
// hand-instantiated PDPW16KD cell's exact synthesizability through THIS
// project's real yosys/nextpnr-ecp5 toolchain (as opposed to Yosys's own
// internal memory-inference path, which maps through DP16KD directly, not
// through a user-visible PDPW16KD instantiation) was not independently
// confirmed via a standalone probe before this file was written -- confirm
// via the real scripts/build_ecp5.ps1 run's own synthesis/PnR logs
// (nonzero PDPW16KD/DP16KD count in Yosys's `stat` output and nextpnr's
// `Device utilisation` line), per this session's own verification
// requirement, rather than trusting this file's correctness from
// documentation alone.
//
// REGMODE("OUTREG"): deliberate 2-cycle read latency, matching
// rtl/top/dfc_mem_sp_512x36.sv's own two pipeline stages exactly (see that
// file's header for the timing-margin rationale). OCER tied high so the
// output register actually updates every cycle.
//
// WRITE/READ MUTUAL EXCLUSION: CEW is gated by we_i (write side engages the
// array only on a real write); CER is tied permanently high (read side
// samples the address bus every cycle). The read and write address buses
// are driven from the SAME addr_i every cycle, but dfc_rtl024_shared_buffer
// (the sole caller) only ever asserts we_i for a genuine write and never
// presents two different clients' requests in the same cycle (the arbiter
// accepts at most one request per CORE_CLK) -- so this is never actually a
// simultaneous same-cycle write-and-read-of-different-addresses situation,
// which is the specific case Lattice's own Memory Usage Guide documents as
// producing unknown read data. See dfc_rtl024_shared_buffer.sv's own header
// for the full read-during-write design.
//
// RESET: RST tied permanently to 1'b0 -- ARCH-BUF-018/RTLSTD-MEM-011
// require physical buffer contents to survive reset (only client-side
// valid/occupancy state resets), so this primitive's own content-clearing
// reset input is deliberately never asserted.

module dfc_mem_sp_512x36 (
  input  logic        clk_i,
  input  logic         we_i,
  input  logic [8:0]   addr_i,
  input  logic [35:0]  wdata_i,
  output logic [35:0]  rdata_o
);

  PDPW16KD #(
    .DATA_WIDTH_W        (36),
    .DATA_WIDTH_R        (36),
    .REGMODE             ("OUTREG"),
    .RESETMODE           ("SYNC"),
    .ASYNC_RESET_RELEASE ("SYNC"),
    // String literals, NOT bit-vector literals (3'b000) -- a real, confirmed
    // nextpnr-ecp5 crash root cause, not a style choice. A bit-vector literal
    // here gets serialized by Yosys into the JSON netlist as a bare numeric-
    // looking string ("000"), which nextpnr's own JSON importer
    // (common/kernel/property.cc's Property::from_string()) misclassifies as
    // a NUMERIC property (any string composed only of [01xz] characters is
    // treated as a bitvector, not a string) -- then ecp5/bitstream.cc's own
    // CSDECODE read (str_or_default, which hard-requires a string) crashes
    // with "Expecting string value but got integer N" (N = the bit pattern's
    // decimal value) once a real PDPW16KD cell reaches that code path (never
    // triggered before RTL-017, since DP16KD/PDPW16KD placement was always
    // 0/208 -- see OPEN_ISSUES.md item 112's full account and the isolated
    // repro that proved this, including the empirical confirmation that
    // changing the bit pattern changes the crash's own printed integer to
    // match exactly). The "0b" prefix (matching the blackbox's own declared
    // default format exactly) is required by Yosys's own CSDECODE parser --
    // a bare "000" string fails synthesis ("error parsing value '000',
    // expected 0b prefix"); the 'b' character is what makes this
    // unambiguously a string to nextpnr's own importer too.
    .CSDECODE_W          ("0b000"),
    .CSDECODE_R          ("0b000"),
    .GSR                 ("AUTO")   // matches Yosys's own working synth_ecp5
                                     // default, not the blackbox's "ENABLED"
                                     // simulation default -- see OPEN_ISSUES.md
  ) u_pdpw16kd (
    // ---- write side ----
    .DI35(wdata_i[35]), .DI34(wdata_i[34]), .DI33(wdata_i[33]), .DI32(wdata_i[32]),
    .DI31(wdata_i[31]), .DI30(wdata_i[30]), .DI29(wdata_i[29]), .DI28(wdata_i[28]),
    .DI27(wdata_i[27]), .DI26(wdata_i[26]), .DI25(wdata_i[25]), .DI24(wdata_i[24]),
    .DI23(wdata_i[23]), .DI22(wdata_i[22]), .DI21(wdata_i[21]), .DI20(wdata_i[20]),
    .DI19(wdata_i[19]), .DI18(wdata_i[18]), .DI17(wdata_i[17]), .DI16(wdata_i[16]),
    .DI15(wdata_i[15]), .DI14(wdata_i[14]), .DI13(wdata_i[13]), .DI12(wdata_i[12]),
    .DI11(wdata_i[11]), .DI10(wdata_i[10]), .DI9(wdata_i[9]),   .DI8(wdata_i[8]),
    .DI7(wdata_i[7]),   .DI6(wdata_i[6]),   .DI5(wdata_i[5]),   .DI4(wdata_i[4]),
    .DI3(wdata_i[3]),   .DI2(wdata_i[2]),   .DI1(wdata_i[1]),   .DI0(wdata_i[0]),
    .ADW8(addr_i[8]), .ADW7(addr_i[7]), .ADW6(addr_i[6]), .ADW5(addr_i[5]),
    .ADW4(addr_i[4]), .ADW3(addr_i[3]), .ADW2(addr_i[2]), .ADW1(addr_i[1]), .ADW0(addr_i[0]),
    .BE3(1'b1), .BE2(1'b1), .BE1(1'b1), .BE0(1'b1),  // whole-word writes only, no partial-word use case
    .CEW(we_i), .CLKW(clk_i), .CSW2(1'b0), .CSW1(1'b0), .CSW0(1'b0),

    // ---- read side ----
    .ADR13(1'b0), .ADR12(1'b0), .ADR11(1'b0), .ADR10(1'b0), .ADR9(1'b0),
    .ADR8(addr_i[8]), .ADR7(addr_i[7]), .ADR6(addr_i[6]), .ADR5(addr_i[5]), .ADR4(addr_i[4]),
    .ADR3(addr_i[3]), .ADR2(addr_i[2]), .ADR1(addr_i[1]), .ADR0(addr_i[0]),
    .CER(1'b1), .OCER(1'b1), .CLKR(clk_i), .CSR2(1'b0), .CSR1(1'b0), .CSR0(1'b0), .RST(1'b0),

    .DO35(rdata_o[35]), .DO34(rdata_o[34]), .DO33(rdata_o[33]), .DO32(rdata_o[32]),
    .DO31(rdata_o[31]), .DO30(rdata_o[30]), .DO29(rdata_o[29]), .DO28(rdata_o[28]),
    .DO27(rdata_o[27]), .DO26(rdata_o[26]), .DO25(rdata_o[25]), .DO24(rdata_o[24]),
    .DO23(rdata_o[23]), .DO22(rdata_o[22]), .DO21(rdata_o[21]), .DO20(rdata_o[20]),
    .DO19(rdata_o[19]), .DO18(rdata_o[18]), .DO17(rdata_o[17]), .DO16(rdata_o[16]),
    .DO15(rdata_o[15]), .DO14(rdata_o[14]), .DO13(rdata_o[13]), .DO12(rdata_o[12]),
    .DO11(rdata_o[11]), .DO10(rdata_o[10]), .DO9(rdata_o[9]),   .DO8(rdata_o[8]),
    .DO7(rdata_o[7]),   .DO6(rdata_o[6]),   .DO5(rdata_o[5]),   .DO4(rdata_o[4]),
    .DO3(rdata_o[3]),   .DO2(rdata_o[2]),   .DO1(rdata_o[1]),   .DO0(rdata_o[0])
  );

endmodule : dfc_mem_sp_512x36
