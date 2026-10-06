// dfc_mem_sp_512x36.sv -- generic/default technology-independent body of the
// Centralized Shared-Buffer Service's single storage port.
//
// Controlling documents: RCA-DFC-ARCH-002 SS12 (ARCH-BUF-020), RCA-DFC-RTL-
// STD-002 RTLSTD-MEM-013, RTLSTD-MOD-008, RTLSTD-WRAP-002.
//
// RTLSTD-MOD-008/RTLSTD-WRAP-002 prohibit vendor memory primitives inside
// technology-independent functional RTL. This file is the technology-
// independent realization RTLSTD-MEM-013 explicitly allows ("...or inferred
// memory"): a plain behavioral single-port RAM, no vendor primitives, used
// for simulation, lint, and formal, and as the default body for any non-
// FPGA-ECP5 target. The real FPGA target uses a DIFFERENT file with the
// SAME module name and port list --
// fpga/ecp5/dfc_mem_sp_512x36_ecp5.sv, instantiating the real Lattice
// PDPW16KD primitive -- swapped in only for the ECP5 build
// (scripts/build_ecp5.ps1 excludes this file and includes that one; see
// that script's own comment at the exclusion/inclusion point). Everywhere
// else (sim.sh/sim.ps1, lint.sh, formal.sh, gate.ps1), this file is what
// actually runs.
//
// LATENCY IS DELIBERATELY NOT THE PRIMITIVE'S MINIMUM. The real PDPW16KD-
// backed realization is configured for 2-cycle address-to-data read latency
// (REGMODE "OUTREG" on the read side, not the minimum "NOREG" 1-cycle mode)
// -- a deliberate choice for extra timing margin on the read path, matching
// this project's own established practice of adding a pipeline register to
// buy margin rather than routing around a tight combinational path (see
// OPEN_ISSUES.md items 41/57, and dfc_rtl024.sv's own rtl013_fault_source_q
// capture register). This file matches that SAME 2-cycle latency exactly,
// not the minimum a behavioral model could get away with -- RTLSTD-WRAP-004/
// RTLSTD-MEM-013 require the two realizations to preserve identical
// observable timing, and a 1-cycle generic body next to a 2-cycle real body
// would be a silent behavioral mismatch between simulation and hardware.
//
// READ-DURING-WRITE: this module has exactly one address port serving both
// write and read (we_i selects which, one operation per cycle -- the
// arbiter in dfc_rtl024_shared_buffer.sv never presents both in the same
// cycle, since it accepts at most one client request per CORE_CLK and this
// is a true single-port device). A write committing to address X and a
// later read of address X therefore always resolve across the normal
// nonblocking-assignment ordering: the write's `mem_q[addr_i] <= wdata_i`
// and the same-edge `read_stage0_q <= mem_q[addr_i]` both read the PRE-edge
// value of mem_q, so a read presented the SAME cycle as a write to the same
// address observes the OLD value (matching the real primitive's WRITEMODE
// "NORMAL" -- "output data does not change... during the write operation");
// a read presented ONE CYCLE LATER (the earliest a different client could
// actually be accepted, since the arbiter never accepts two requests in one
// cycle) observes the write's committed value, because that write already
// landed a full clock edge earlier. This is the deliberately chosen,
// explicitly tested RDW behavior (RTLSTD-MEM-013) -- see
// verification/testbench/rtl-024/rtl024_buffer_tb.sv's P_RDW case.
//
// RESET: ARCH-BUF-018/RTLSTD-MEM-011 -- "physical memory contents are not
// cleared by reset." mem_q genuinely has no reset branch below; this is the
// real primitive's natural behavior (block RAM contents are undefined/
// retained across a logic reset, not zeroed), not an oversight.

module dfc_mem_sp_512x36 (
  input  logic        clk_i,
  input  logic         we_i,
  input  logic [8:0]   addr_i,
  input  logic [35:0]  wdata_i,
  output logic [35:0]  rdata_o
);

  logic [35:0] mem_q [0:511];   // contents deliberately never reset -- see header
  logic [35:0] read_stage0_q;   // NOREG-equivalent stage: address-registered array read
  logic [35:0] read_stage1_q;   // OUTREG-equivalent stage: +1 cycle, matches real primitive

  always_ff @(posedge clk_i) begin
    if (we_i) mem_q[addr_i] <= wdata_i;
    read_stage0_q <= mem_q[addr_i];
    read_stage1_q <= read_stage0_q;
  end

  assign rdata_o = read_stage1_q;

endmodule : dfc_mem_sp_512x36
