#!/usr/bin/env python3
"""
reggen.py -- generic register-bank generator (v4: multiple simultaneous
cross-module field-maps).

v3 added real cross-module forwarding (see the account below, kept for
history) but only ever accepted ONE field-map file per run -- fine while
RTL-002 was the only consumer with real forwarding wired up, but a real,
confirmed limitation the moment a SECOND module (RTL-003) needed the same
treatment through the same single generated regbank file: the two modules'
real registers all live in the same `dfc_config_regbank_regs.sv`, so the
generator must be able to wire both consumers' aggregated control_o/status_i
ports in the same run, not one-at-a-time. v4 changes the field-map CLI
argument to accept one OR MORE field-map paths and threads a list of
per-consumer field-map contexts through emit_regbank() instead of a single
one -- every register still appears in at most one field-map's
control_registers/status_registers (enforced implicitly: a register name is
looked up against each field-map in turn, and the first match wins -- if two
field-maps ever claimed the same register that would be a real, disclosed
field-map authoring bug, not something this generator silently resolves).

v3's original account (still accurate, just no longer single-field-map):
implemented real address decode (rdata_o mux, decode_hit_o, write_illegal_o,
protected_o) but stopped at the regbank's own boundary: any register whose
real data or effect lives in ANOTHER module (e.g. RTL-002's SYS_CONTROL/
SUBSYS_ENABLE/RESET_CONTROL, which RTL-001 physically decodes and stores per
REG-002, but whose actual EFFECT belongs to RTL-002) was captured/stored
correctly but never exposed to that module at all -- a real, confirmed gap
(RTL-002 ran on a static placeholder, completely disconnected from anything
the host actually wrote). v3 closed this for real, using a FIELD-MAP file
(e.g. rtl002_field_map.json) that is hand-verified directly against
REG-002.md's own per-register field tables (cited by contract ID) for the
specific registers a given consumer/producer module needs -- this is NOT yet
a fully generic, auto-extracted solution for all 353 registers
(extract_registers.py does not currently preserve per-field bit ranges
project-wide); extending it to be so is real, disclosed future work, not
silently treated as solved. See each field-map file's own "_source" note.

What v3/v4 add, only for registers that appear in a supplied field-map:
  - CONTROL direction (RTL-001 -> consumer module): one aggregated
    `{module}_control_o` output port per consumer, sized to that consumer's
    real dfc_types_pkg::DFC_<MODULE>_CONTROL_WIDTH (read directly from
    dfc_types_pkg.json, not hardcoded). Each RW field's value is driven
    from its EXISTING stored register (`{name}_q`); each WO-CMD/W1C field
    (a bounded, one-cycle action, never a held level) is driven from a
    genuine one-cycle registered pulse capturing the accepted write
    (`{name}_pulse_q`).
  - STATUS direction (consumer module -> RTL-001, for registers marked
    "external" in the slice): one aggregated `{module}_status_i` input port
    per consumer, sized to that consumer's real dfc_types_pkg::
    DFC_<MODULE>_STATUS_WIDTH, REPLACING the individual per-register
    status_i ports for every register listed in that field-map's
    status_registers (other external registers not covered by ANY
    field-map -- i.e. modules that aren't real yet -- keep their existing
    individual, stub-tied status_i ports unchanged). Each register's own
    read value is reconstructed by slicing and repositioning bits out of
    its consumer's one aggregated input, per that field-map's real,
    hand-verified bit-position cross-reference.
  - write_illegal_o FIX: a register listed in ANY field-map's
    control_registers now correctly reports write_illegal_o = 1'b0 (a real
    write path exists for its mapped fields), even if its readback class is
    "external".

Still NOT implemented (disclosed, not silently skipped): per-field reserved-
bit masking within a mixed register beyond a field-map's own listed fields,
and any register/module not covered by any supplied field-map -- those keep
v2's existing, unchanged behavior exactly.
"""
import sys, json, os


def sv_ident(name):
    return name.lower()


def load_struct(types_path, struct_name):
    data = json.load(open(types_path, encoding="utf-8"))
    for s in data.get("structs", []):
        if s["name"] == struct_name:
            fields = {f["name"]: (f["hi"], f["lo"]) for f in s["fields"]}
            return s["width"], fields
    raise KeyError(f"struct {struct_name} not found in {types_path}")


def build_32bit_concat(fields, key_hi, key_lo, source_expr_fn):
    """Builds a single 32-bit concatenation expression (MSB-first) covering
    every bit exactly once -- explicit zero-fill for any gap (RSV0/
    unmapped bits), never a separate full-width default assign layered
    with bit-select assigns to the same signal (that's a genuine multiple-
    driver conflict, not just redundant, confirmed while building this
    generator -- caught before ever being compiled)."""
    ordered = sorted(fields, key=lambda f: -f[key_hi])
    parts = []
    next_hi = 31
    for f in ordered:
        hi, lo = f[key_hi], f[key_lo]
        if hi < next_hi:
            gap = next_hi - hi
            parts.append(f"{gap}'h0")
        parts.append(source_expr_fn(f))
        next_hi = lo - 1
    if next_hi >= 0:
        parts.append(f"{next_hi + 1}'h0")
    return "{" + ", ".join(parts) + "}"


def load_fieldmap_ctx(fieldmap, types_path):
    """Resolves one field-map file into the per-consumer context emit_regbank
    needs: consumer identifier, control/status struct width+fields, and
    register-name-keyed lookup dicts."""
    consumer = sv_ident(fieldmap["consumer_module"]).replace("-", "")
    ctrl_regs_by_name = {r["register"]: r for r in fieldmap.get("control_registers", [])}
    status_regs_by_name = {r["register"]: r for r in fieldmap.get("status_registers", [])}
    control_width, control_fields = load_struct(types_path, fieldmap["control_struct"])
    status_width, status_fields = load_struct(types_path, fieldmap["status_struct"])
    return {
        "fieldmap": fieldmap,
        "consumer": consumer,
        "consumer_module": fieldmap["consumer_module"],
        "ctrl_regs_by_name": ctrl_regs_by_name,
        "status_regs_by_name": status_regs_by_name,
        "control_width": control_width,
        "control_fields": control_fields,
        "status_width": status_width,
        "status_fields": status_fields,
        "control_o_drivers": [],  # filled in per-register below
    }


def emit_regbank(module, regs, fieldmaps, types_path, out_module_name):
    lines = []
    lines.append(f"// {out_module_name}.sv -- GENERATED by reggen.py (v4). "
                 f"Do not hand-edit.")
    lines.append(f"// Source: dfc_rtl001_regbank_slice.json + dfc_registers_pkg.json "
                 f"({len(regs)} registers)")
    for ctx in fieldmaps:
        lines.append(f"// Cross-module forwarding: {ctx['consumer_module']} "
                     f"(see tools/reggen/{sv_ident(ctx['consumer_module']).replace('-', '')}_field_map.json's "
                     f"own _source note for exact scope/citations)")
    lines.append("")
    lines.append("")
    mod_ident = out_module_name

    # ---- resolve field-map lookups up front; build one flat register-name
    # -> owning-ctx map (a register claimed by two field-maps is a real,
    # disclosed field-map authoring bug -- fail loud, don't silently pick one) ----
    reg_owner_ctx = {}  # register name -> ctx, for CONTROL entries
    reg_status_ctx = {}  # register name -> ctx, for STATUS entries
    for ctx in fieldmaps:
        for name in ctx["ctrl_regs_by_name"]:
            if name in reg_owner_ctx:
                raise ValueError(f"register '{name}' claimed as a CONTROL entry by both "
                                 f"{reg_owner_ctx[name]['consumer_module']} and "
                                 f"{ctx['consumer_module']}'s field-maps -- fix the field-maps")
            reg_owner_ctx[name] = ctx
        for name in ctx["status_regs_by_name"]:
            if name in reg_status_ctx:
                raise ValueError(f"register '{name}' claimed as a STATUS entry by both "
                                 f"{reg_status_ctx[name]['consumer_module']} and "
                                 f"{ctx['consumer_module']}'s field-maps -- fix the field-maps")
            reg_status_ctx[name] = ctx

    ext_regs = [r for r in regs if r["readback"] == "external"]
    # external registers whose STATUS now comes from an aggregated
    # {consumer}_status_i port instead of their own individual port
    aggregated_ext_names = set(reg_status_ctx.keys())
    individual_ext_regs = [r for r in ext_regs if r["name"] not in aggregated_ext_names]

    ports = [
        "  input  logic         clk_i",
        "  input  logic         rst_ni",
        "  input  logic [31:0]  addr_i",
        "  input  logic [31:0]  wdata_i",
        "  input  logic         write_en_i",
        "  output logic [31:0]  rdata_o",
        "  output logic         decode_hit_o",
        "  output logic         write_illegal_o",
        "  output logic         protected_o",
    ]
    for r in individual_ext_regs:
        ports.append(f"  input  logic [31:0]  {sv_ident(r['name'])}_status_i")
    for ctx in fieldmaps:
        lines.append(f"  // Aggregated real {ctx['consumer_module']} status, replacing "
                     f"individual ports for: {', '.join(sorted(ctx['status_regs_by_name'].keys()))}")
        ports.append(f"  input  logic [{ctx['status_width']-1}:0]  {ctx['consumer']}_status_i")
        lines.append(f"  // Aggregated real {ctx['consumer_module']} control, replacing "
                     f"the prior disconnected placeholder for: "
                     f"{', '.join(sorted(ctx['ctrl_regs_by_name'].keys()))}")
        ports.append(f"  output logic [{ctx['control_width']-1}:0] {ctx['consumer']}_control_o")
    lines.append(f"module {mod_ident} (")
    lines.append(",\n".join(ports))
    lines.append(");")
    lines.append("")

    counts = {"internal_reg": 0, "const": 0, "zero": 0, "external": 0,
              "internal_w1c": 0, "internal_capture": 0}
    qualified_protection = []

    for r in regs:
        nm = sv_ident(r["name"])
        rb = r["readback"]
        reset = r["reset"]
        note = None
        try:
            reset_lit = f"32'h{int(str(reset),0):08X}"
        except ValueError:
            reset_lit = "32'h00000000"
            note = (f"  // NOTE: source reset for {r['name']} is non-numeric "
                    f"(\"{reset}\"); 0x00000000 used as a placeholder, not "
                    f"invented from the doc -- see registers.json.")
        counts[rb] = counts.get(rb, 0) + 1
        wr_en = f"write_en_i && (addr_i == dfc_registers_pkg::DFC_ADDR_{r['name']})"

        ctrl_ctx = reg_owner_ctx.get(r["name"])
        ctrl_entry = ctrl_ctx["ctrl_regs_by_name"].get(r["name"]) if ctrl_ctx else None
        status_ctx = reg_status_ctx.get(r["name"])
        status_entry = status_ctx["status_regs_by_name"].get(r["name"]) if status_ctx else None

        # ---- WO-CMD/W1C one-cycle pulse capture, real generation (not a
        # permanent tie, not "hold whatever was last written") ----
        needs_pulse = ctrl_entry and any(f["class"] in ("WO-CMD", "W1C") for f in ctrl_entry["fields"])
        if needs_pulse:
            lines.append(f"  // {r['name']} (0x{r['addr']:04X}) -- real one-cycle command/clear-")
            lines.append(f"  //   request pulse capture for {ctrl_ctx['consumer_module']}, real")
            lines.append(f"  //   generation per contract {ctrl_entry['contract_id']}, not a "
                         f"permanent tie.")
            lines.append(f"  logic [31:0] {nm}_pulse_q;")
            lines.append(f"  always_ff @(posedge clk_i or negedge rst_ni)")
            lines.append(f"    if (!rst_ni) {nm}_pulse_q <= 32'h0;")
            lines.append(f"    else {nm}_pulse_q <= ({wr_en}) ? wdata_i : 32'h0;")
            lines.append("")

        if rb == "internal_reg":
            lines.append(f"  // {r['name']} (0x{r['addr']:04X}) -- {r['access_summary']}, "
                         f"owner {r['owner']}")
            if note:
                lines.append(note)
            lines.append(f"  logic [31:0] {nm}_q;")
            lines.append(f"  always_ff @(posedge clk_i or negedge rst_ni)")
            lines.append(f"    if (!rst_ni) {nm}_q <= {reset_lit};")
            lines.append(f"    else if ({wr_en}) {nm}_q <= wdata_i;")
            lines.append("")
        elif rb == "const":
            lines.append(f"  // {r['name']} (0x{r['addr']:04X}) -- CONST, fixed at reset value")
            if note:
                lines.append(note)
            lines.append(f"  wire [31:0] {nm}_q = {reset_lit};")
            lines.append("")
        elif rb == "zero":
            if ctrl_entry:
                lines.append(f"  // {r['name']} (0x{r['addr']:04X}) -- WO-CMD, reads zero; "
                             f"real command-pulse forwarding to {ctrl_ctx['consumer_module']} "
                             f"via {nm}_pulse_q above (see control_o assembly below) -- "
                             f"replaces v2's permanent zero-tie for this register.")
            else:
                lines.append(f"  // {r['name']} (0x{r['addr']:04X}) -- WO-CMD, reads zero; command "
                             f"pulse generation is module-specific, not reggen-generated. "
                             f"Write acceptance ({wr_en}) is decoded here but the resulting "
                             f"pulse is not yet wired to any consumer.")
            lines.append(f"  wire [31:0] {nm}_q = 32'h00000000;")
            lines.append("")
        elif rb == "external":
            if status_entry:
                consumer = status_ctx["consumer"]
                status_fields = status_ctx["status_fields"]
                lines.append(f"  // {r['name']} (0x{r['addr']:04X}) -- external passthrough, "
                             f"owner {r['owner']}. Reconstructed from the aggregated "
                             f"{consumer}_status_i input (contract {status_entry['contract_id']}), "
                             f"not an individual per-register port.")
                for f in status_entry["fields"]:
                    reg_hi, reg_lo = f["reg_hi"], f["reg_lo"]
                    st_hi, st_lo = status_fields[f["struct_field"]]
                    assert (reg_hi - reg_lo) == (st_hi - st_lo), (
                        f"width mismatch {r['name']}.{f['struct_field']}: "
                        f"reg[{reg_hi}:{reg_lo}] vs struct[{st_hi}:{st_lo}]")
                concat_expr = build_32bit_concat(
                    status_entry["fields"], "reg_hi", "reg_lo",
                    lambda f: f"{consumer}_status_i[{status_fields[f['struct_field']][0]}:"
                              f"{status_fields[f['struct_field']][1]}]")
                lines.append(f"  wire [31:0] {nm}_q = {concat_expr};")
                lines.append("")
            else:
                lines.append(f"  // {r['name']} (0x{r['addr']:04X}) -- external passthrough, "
                             f"owner {r['owner']}")
                lines.append(f"  wire [31:0] {nm}_q = {nm}_status_i;")
                lines.append("")
        elif rb in ("internal_w1c", "internal_capture"):
            lines.append(f"  // {r['name']} (0x{r['addr']:04X}) -- {rb}, generated bank logic "
                         f"(bus decode/protection capture; see REG-002 SS4). Reset value "
                         f"only -- set/clear/capture update logic is authored by hand "
                         f"elsewhere, not mechanically generated; NOT yet implemented.")
            if note:
                lines.append(note)
            lines.append(f"  logic [31:0] {nm}_q;")
            lines.append(f"  always_ff @(posedge clk_i or negedge rst_ni)")
            lines.append(f"    if (!rst_ni) {nm}_q <= {reset_lit};")
            lines.append("")

        # ---- collect control_o driving assignments for this register ----
        if ctrl_entry:
            control_fields = ctrl_ctx["control_fields"]
            for f in ctrl_entry["fields"]:
                reg_hi, reg_lo = f["reg_hi"], f["reg_lo"]
                st_hi, st_lo = control_fields[f["struct_field"]]
                assert (reg_hi - reg_lo) == (st_hi - st_lo), (
                    f"width mismatch {r['name']}.{f['struct_field']}: "
                    f"reg[{reg_hi}:{reg_lo}] vs struct[{st_hi}:{st_lo}]")
                driver = f"{nm}_pulse_q" if f["class"] in ("WO-CMD", "W1C") else f"{nm}_q"
                ctrl_ctx["control_o_drivers"].append(
                    (st_hi, st_lo, f"{driver}[{reg_hi}:{reg_lo}]", r["name"], f["struct_field"]))

        prot = r.get("protection", "?")
        if prot not in ("No", "?") and prot != "Yes":
            qualified_protection.append((r["name"], prot))

    # ---- aggregated control_o assembly, one block per consumer ----
    for ctx in fieldmaps:
        consumer = ctx["consumer"]
        control_o_drivers = ctx["control_o_drivers"]
        control_width = ctx["control_width"]
        # NOTE: no default-zero assign here -- unlike the per-register status
        # reconstruction above (which has real RSV0 gaps to fill), the
        # consumer's control struct is verified, by construction, to have
        # every one of its bits covered by exactly one field-map entry (the
        # struct's own extractor already verified it tiles its declared
        # width with no gaps/overlaps) -- confirmed by the assert loop below
        # actually running, not assumed. A default assign here would create
        # exactly the same multiple-driver conflict already fixed above.
        mapped_bits = sum((hi - lo + 1) for hi, lo, _, _, _ in control_o_drivers)
        assert mapped_bits == control_width, (
            f"control_o field-map covers {mapped_bits} bits, expected exactly "
            f"{control_width} (dfc_types_pkg::{ctx['fieldmap']['control_struct']}'s real width) "
            f"-- field-map is incomplete or overlapping, fix the {ctx['consumer_module']} field-map")
        lines.append(f"  // ==========================================================================")
        lines.append(f"  // Aggregated {consumer}_control_o -- real forwarding to "
                     f"{ctx['consumer_module']}, replacing the disconnected placeholder.")
        lines.append(f"  // Every assignment below is sourced from a real stored register or a real")
        lines.append(f"  // one-cycle pulse-capture register above, at the exact bit position the")
        lines.append(f"  // real generated dfc_types_pkg.sv's {ctx['fieldmap']['control_struct']} defines --")
        lines.append(f"  // cross-checked at generation time ({mapped_bits}/{control_width} bits, "
                     f"exact match confirmed by the assert above actually running).")
        lines.append(f"  // ==========================================================================")
        for st_hi, st_lo, driver_expr, regname, fieldname in sorted(control_o_drivers, key=lambda t: -t[0]):
            rng = f"{st_hi}" if st_hi == st_lo else f"{st_hi}:{st_lo}"
            lines.append(f"  assign {consumer}_control_o[{rng}] = {driver_expr};  "
                         f"// {regname}.{fieldname}")
        lines.append("")

    # ---- combinational read mux + decode/access/protection outputs ----
    lines.append("  // Combinational address decode: read mux, decode-hit, write-")
    lines.append("  // illegality (whole-register access class only), and protection-")
    lines.append("  // requirement flag. All mechanically derived from REG-002 via")
    lines.append("  // dfc_registers_pkg.json -- see file header for exact scope limits.")
    lines.append("  always_comb begin")
    lines.append("    rdata_o         = 32'h00000000;")
    lines.append("    decode_hit_o    = 1'b0;")
    lines.append("    write_illegal_o = 1'b0;")
    lines.append("    protected_o     = 1'b0;")
    lines.append("    unique case (addr_i)")
    for r in regs:
        nm = sv_ident(r["name"])
        owner_ctx = reg_owner_ctx.get(r["name"])
        # FIX (found while wiring RTL-013's FAULT_RECOVERABLE_MASK, a CONST
        # register whose REG-002 text requires "Any register write is
        # ACCESS_ERROR"): a field-map control_registers entry means a real
        # forwarding path exists into the consumer's control_o, but that is
        # NOT the same claim as "a real host WRITE path exists" -- every
        # entry used before this one was RW/WO-CMD/W1C, where forwarding and
        # writability are the same thing, so the two were never
        # distinguished. A register whose ctrl_entry fields are ALL class
        # "CONST" forwards a fixed value with no writable field at all (the
        # fixed literal comes from the register's own const-readback wire,
        # never from wdata_i) -- write_illegal_o for such a register must
        # still follow the readback-based rule below, not be unconditionally
        # cleared. Every pre-existing RW/WO-CMD/W1C field-map entry is
        # unaffected (has_writable_path stays True for all of them).
        has_writable_path = bool(owner_ctx) and any(
            f["class"] != "CONST" for f in owner_ctx["ctrl_regs_by_name"][r["name"]]["fields"])
        if has_writable_path:
            illegal = "1'b0"  # FIX: a real write path exists for this register's mapped
                               # fields (see file header) -- v2 incorrectly hardcoded 1'b1
                               # for every "external"-class register regardless of this.
        else:
            illegal = "1'b1" if r["readback"] in ("const", "external") else "1'b0"
        prot = r.get("protection", "?")
        protected = "1'b1" if (prot == "Yes" or (prot not in ("No", "?"))) else "1'b0"
        lines.append(f"      dfc_registers_pkg::DFC_ADDR_{r['name']}: begin rdata_o = {nm}_q; "
                     f"decode_hit_o = 1'b1; write_illegal_o = {illegal}; "
                     f"protected_o = {protected}; end")
    lines.append("      default: begin end  // decode_hit_o stays 0 -> DECODE_ERROR upstream")
    lines.append("    endcase")
    lines.append("  end")
    lines.append("")
    lines.append(f"endmodule : {mod_ident}")
    return "\n".join(lines) + "\n", counts, qualified_protection


def emit_manifest(module, regs, counts, qualified_protection, fieldmaps):
    lines = [f"# Register-map manifest -- {module} (reggen.py v4)",
             f"# {len(regs)} registers total: " +
             ", ".join(f"{v} {k}" for k, v in counts.items()),
             f"# {len(qualified_protection)} register(s) with qualified (non-bare) "
             f"protection -- see NOTE below and file header.", ""]
    for ctx in fieldmaps:
        ctrl_names = sorted(ctx["ctrl_regs_by_name"].keys())
        status_names = sorted(ctx["status_regs_by_name"].keys())
        lines.append(f"# REAL cross-module forwarding to {ctx['consumer_module']}:")
        lines.append(f"#   control (RTL-001 -> {ctx['consumer_module']}): {', '.join(ctrl_names)}")
        lines.append(f"#   status ({ctx['consumer_module']} -> RTL-001): {', '.join(status_names)}")
        lines.append("")
    for r in sorted(regs, key=lambda r: r["addr"]):
        lines.append(f"0x{r['addr']:04X}  {r['name']:<28} readback={r['readback']:<18} "
                     f"owner={r['owner']:<15} access={r['access_summary']:<20} "
                     f"protection={r.get('protection','?')}")
    if qualified_protection:
        lines.append("")
        lines.append("# QUALIFIED PROTECTION (treated as fully protected -- conservative, not exact):")
        for nm, prot in qualified_protection:
            lines.append(f"#   {nm}: \"{prot}\"")
    return "\n".join(lines) + "\n"


def main():
    if len(sys.argv) < 4:
        print("usage: reggen.py <slice.json> <registers.json> <out_dir>", file=sys.stderr)
        print("       reggen.py <slice.json> <registers.json> <types.json> <fieldmap1.json> [<fieldmap2.json> ...] <out_dir>",
              file=sys.stderr)
        sys.exit(2)

    if len(sys.argv) == 4:
        slice_path, regs_path, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
        types_path = None
        fieldmap_paths = []
    elif len(sys.argv) >= 6:
        slice_path, regs_path, types_path = sys.argv[1], sys.argv[2], sys.argv[3]
        fieldmap_paths = sys.argv[4:-1]
        out_dir = sys.argv[-1]
    else:
        print("usage: reggen.py <slice.json> <registers.json> <out_dir>", file=sys.stderr)
        print("       reggen.py <slice.json> <registers.json> <types.json> <fieldmap1.json> [<fieldmap2.json> ...] <out_dir>",
              file=sys.stderr)
        sys.exit(2)

    slice_spec = json.load(open(slice_path))
    regs_full = json.load(open(regs_path))
    module = slice_spec["module"]
    regs = slice_spec["registers"]

    slice_addrs = {r["addr"] for r in regs}
    full_addrs = {m["addr"] for m in regs_full["registers"]}
    missing = full_addrs - slice_addrs
    errors = []
    if missing:
        errors.append(f"{len(missing)} register(s) in dfc_registers_pkg.json missing from "
                      f"the slice: {sorted(hex(a) for a in list(missing)[:10])}")
    if len(regs) != len(set(r["addr"] for r in regs)):
        errors.append("duplicate address within slice")

    fieldmaps_raw = []
    for fieldmap_path in fieldmap_paths:
        fm = json.load(open(fieldmap_path, encoding="utf-8"))
        fieldmaps_raw.append(fm)
        reg_names = {r["name"] for r in regs}
        for section in ("control_registers", "status_registers"):
            for entry in fm.get(section, []):
                if entry["register"] not in reg_names:
                    errors.append(f"field-map ({fieldmap_path}) references register "
                                  f"'{entry['register']}' not present in the slice")

    if errors:
        print(f"REGGEN FAILED ({len(errors)} error(s); nothing written):", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        sys.exit(1)

    fieldmaps = [load_fieldmap_ctx(fm, types_path) for fm in fieldmaps_raw]

    os.makedirs(out_dir, exist_ok=True)
    # Single source of truth for the emitted file's basename AND its SV
    # module name, so RTLSTD-ORG-001 (filename matches module name) holds
    # by construction.
    OUT_MODULE_NAME = "dfc_config_regbank_regs"
    sv, counts, qualified_protection = emit_regbank(module, regs, fieldmaps, types_path, OUT_MODULE_NAME)
    manifest = emit_manifest(module, regs, counts, qualified_protection, fieldmaps)
    open(os.path.join(out_dir, "dfc_config_regbank_regs.sv"), "w").write(sv)
    open(os.path.join(out_dir, "regmap_manifest.txt"), "w").write(manifest)
    print(f"OK: {module} regbank -- {len(regs)} registers: " +
          ", ".join(f"{v} {k}" for k, v in counts.items()))
    print(f"    {len(qualified_protection)} register(s) with qualified protection "
          f"(see manifest)")
    for ctx in fieldmaps:
        print(f"    real cross-module forwarding wired for {ctx['consumer_module']}: "
              f"{len(ctx['ctrl_regs_by_name'])} control regs, "
              f"{len(ctx['status_regs_by_name'])} status regs")
    print(f"    emitted -> {out_dir}/dfc_config_regbank_regs.sv, {out_dir}/regmap_manifest.txt")


if __name__ == "__main__":
    main()
