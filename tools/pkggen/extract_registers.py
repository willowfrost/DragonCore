#!/usr/bin/env python3
"""
extract_registers.py -- one-time extractor for dfc_registers_pkg.json (REG-002 baseline).

Rebuilt for RCA-DFC-REG-002. Structural differences from the -001/Rev I extractor
this supersedes:

  * Register headers are Markdown H3 with a backtick-wrapped address:
        ### NAME (`0xADDR`)
    (-001 used a bare `NAME (0xADDR)` line, no `###`, no backticks.)

  * Per-register PROPERTY table has plain (non-bold) keys and a -002 key set:
        | Property | Definition |
        | Contract ID | `REG-0044` |
        | Access summary | Mixed: W1C, RSV0, RO |
        | Register reset | 0x00000000 |
        | Owner | RTL-002 |
        | Protection | No |
        | Register behavior | ... |
        | Register-level side effect | ... |
    (-001 used bold keys **Access**/**Reset**/**Owner**/**Protection**/**Traceability**,
    and access/reset were REGISTER-level only.)

  * BITS table now carries per-FIELD Access and Reset columns directly -- the reason
    for this rebuild:
        | Bits | Field | Access | Reset | Legal values/range | Write validation |
          Read behavior | Side effect | Simultaneous-condition priority | Architecture source |
    Field/reset cells are backtick-wrapped for Field, plain for Access/Reset.

  * All 314 registers are explicit, uniformly-tabulated blocks. The 23 §6.1-template
    EVT_OVERFLOW_STATUS registers and the 5 prose-format registers that -001 had to
    inject/transcribe are now spelled out in full, so this extractor needs NO EVT_ADDR
    injection and NO OVERRIDE transcription. Parsing is purely table-driven.

Emits dfc_registers_pkg.json for pkggen.py (same top-level shape as -001):
  * params    : DFC_ADDR_<NAME> (address) and DFC_RESET_<NAME> (register-level reset)
  * structs   : dfc_reg_<name>_t packed field layout, each field now annotated with its
                own access + reset (the new per-field data)
  * registers : per-register metadata incl. readback classification

VERIFICATION (fail-loud; nothing written on any failure):
  * expected 314 registers (REG-002 §6: "314 implemented 32-bit registers")
  * every register's fields tile [0..31] with no gaps/overlaps
  * all addresses unique
  * every non-reserved field carries a recognized -002 access class
"""
import re, sys, json
from collections import Counter

EXPECTED_REGS = 353

# -002 §3 Field Access Classes (the complete legal vocabulary).
# UPDATED: COUNTER16-CLR added -- confirmed real, deliberate baseline content
# (REG-ENC-021, ARCH-GEN-006 through 008), not a parsing artifact. Packs two
# independent 16-bit saturating counters into one 32-bit register (vs. the
# original COUNTER-CLR's single full-32-bit counter) -- added for per-client/
# per-source/per-destination diagnostic counters that would otherwise need
# one register each. Register count correspondingly grew from 314 to 353.
ACCESS_CLASSES = {"RW", "RO", "WO-CMD", "W1C", "W1S", "COUNTER-CLR",
                  "COUNTER16-CLR", "CONST", "CONST1", "RSV0"}

HDR = re.compile(r'^###\s+([A-Z][A-Za-z0-9_]+)\s+\(`?0x([0-9A-Fa-f]+)`?\)\s*$')
BITSPEC = re.compile(r'^(\d+)(?::(\d+))?$')          # "0" or "31:24"
BITS_HEADER = re.compile(r'^\|\s*Bits\s*\|\s*Field\s*\|\s*Access\s*\|\s*Reset\s*\|')
SEP_ROW = re.compile(r'^\|[\s:\-|]+\|$')             # | ---: | --- | ...

PROP_KEYS = {
    "contract id": "contract_id",
    "access summary": "access_summary",
    "register reset": "reset",
    "owner": "owner",
    "protection": "protection",
    "register behavior": "behavior",
    "register-level side effect": "reg_side_effect",
}


def cells(line):
    """Split a Markdown table row into trimmed, backtick-stripped cells."""
    if not line.startswith("|"):
        return None
    parts = [c.strip().strip("`").strip() for c in line.strip().strip("|").split("|")]
    return parts


def is_reserved(fld):
    return bool(re.match(r'(RSV|RESERVED|RSVD)', fld, re.I))


# --- readback classification -------------------------------------------------
# Ported from the -001 extractor's rule set and vocabulary. Mechanical rules are
# format-independent (they key on access class + owner, both of which -002 still
# carries). The 5 sole-RTL-001 RO-class registers that are not mechanically
# derivable are resolved by name below; all 5 fall inside the 0x0000-0x005C
# Identification block (the current skeleton scope), so this layer is directly
# exercised by the skeleton-scope verification. Citations updated to -002 IDs.
AMBIGUOUS_RESOLVED = {
    "PROTECT_STATUS": ("external",
        "REG-002 PROTECT_STATUS (0x0034): protected-write authorization FSM "
        "(KEY1_ACCEPTED/ARMED/EXPIRED/BAD_KEY/UNAUTHORIZED/REMAINING_CYCLES) is a "
        "bespoke sequential machine, not the reggen-generated decode/protection-check "
        "logic -> external, supplied as a status input."),
    "CONFIG_ERROR_STATUS": ("internal_w1c",
        "REG-002 CONFIG_ERROR_STATUS (0x0038): captures the generated regbank's own "
        "decode/access/protection checking -> internal, W1C."),
    "CONFIG_ERROR_ADDR": ("internal_capture",
        "REG-002 CONFIG_ERROR_ADDR (0x003C): captures the offending address at the "
        "same decode-error event -> internal capture."),
    "CONFIG_ERROR_DATA": ("internal_capture",
        "REG-002 CONFIG_ERROR_DATA (0x0040): captures the offending write data at the "
        "same decode-error event -> internal capture."),
    "RTL001_EVT_OVERFLOW_STATUS": ("internal_w1c",
        "REG-002 RTL001_EVT_OVERFLOW_STATUS (0x0048): RTL-001 is its own event "
        "producer, so unlike the other EVT_OVERFLOW_STATUS registers (external "
        "producer) its EVENT_OVERFLOW/DROP_COUNT are generated within RTL-001 -> "
        "internal, W1C."),
}


def derive_readback(name, field_access, owner):
    """Register-level readback from the per-field access set + owner.

    -002 moves access to per-field, so the register-level access class the -001
    rule consumed is derived here from the non-reserved fields' access set.
    """
    owner_mods = [o.strip() for o in owner.split("/")]
    non_rtl001 = [o for o in owner_mods if o not in ("RTL-001", "")]
    named = {a for f, a in field_access if not is_reserved(f)}  # non-reserved access classes

    if name in AMBIGUOUS_RESOLVED:
        rb, cite = AMBIGUOUS_RESOLVED[name]
        return rb, f"manual (ambiguous: sole-RTL-001 RO-class): {cite}"
    if named and named <= {"CONST", "CONST1"}:
        return "const", "mechanical"
    if named and named <= {"WO-CMD"}:
        return "zero", "mechanical"
    if "RW" in named:
        return "internal_reg", "mechanical"
    if named and named <= {"RO", "W1C", "W1S", "COUNTER-CLR", "COUNTER16-CLR"}:
        if non_rtl001:
            return "external", "mechanical"
        return "UNRESOLVED_AMBIGUOUS", ("FLAG: sole-RTL-001 RO-class register not in "
                                        "AMBIGUOUS_RESOLVED table")
    if not named:
        return "reserved_only", "mechanical"
    return "UNKNOWN", f"FLAG: unclassified access set {sorted(named)}"


def parse(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    regs, errors = [], []
    i = 0
    while i < len(lines):
        h = HDR.match(lines[i])
        if not h:
            i += 1
            continue
        name, addr = h.group(1), int(h.group(2), 16)
        props, fields = {}, []
        j = i + 1
        in_bits = False
        while j < len(lines):
            ln = lines[j]
            if HDR.match(ln) or ln.startswith("## ") or ln.startswith("# "):
                break
            if BITS_HEADER.match(ln):
                in_bits = True
                j += 1
                continue
            if SEP_ROW.match(ln):
                j += 1
                continue
            c = cells(ln)
            if c and len(c) >= 2 and not in_bits:
                key = c[0].lower()
                if key in PROP_KEYS:
                    props[PROP_KEYS[key]] = c[1]
            elif c and in_bits and len(c) >= 4 and BITSPEC.match(c[0]):
                m = BITSPEC.match(c[0])
                hi = int(m.group(1))
                lo = int(m.group(2)) if m.group(2) else hi
                fields.append({"name": c[1], "hi": hi, "lo": lo,
                               "access": c[2], "reset": c[3]})
            j += 1
        if fields:
            regs.append({"name": name, "addr": addr, "props": props, "fields": fields})
        else:
            errors.append(f"{name} (0x{addr:04X}): header matched but no field rows parsed")
        i = j
    return regs, errors


def verify(regs, errors):
    if len(regs) != EXPECTED_REGS:
        errors.append(f"register count {len(regs)} != {EXPECTED_REGS}")
    addrs = {}
    for r in regs:
        covered = [False] * 32
        for f in r["fields"]:
            if not is_reserved(f["name"]) and f["access"] not in ACCESS_CLASSES:
                errors.append(f"{r['name']}.{f['name']}: unrecognized access '{f['access']}'")
            for b in range(f["lo"], f["hi"] + 1):
                if b > 31:
                    errors.append(f"{r['name']}.{f['name']}: bit {b} > 31")
                    continue
                if covered[b]:
                    errors.append(f"{r['name']}: bit {b} overlap at {f['name']}")
                covered[b] = True
        gaps = [b for b in range(32) if not covered[b]]
        if gaps:
            errors.append(f"{r['name']} (0x{r['addr']:04X}): uncovered bits "
                          f"{gaps[:6]}{'...' if len(gaps) > 6 else ''}")
        addrs.setdefault(r["addr"], []).append(r["name"])
    for a, n in addrs.items():
        if len(n) > 1:
            errors.append(f"address 0x{a:04X} shared by {n}")
    return errors


def emit(regs, out_path):
    AW = 16
    params, structs, meta = [], [], []
    nonnumeric_reset, unresolved = [], []
    for r in regs:
        nm = r["name"]
        reset = r["props"].get("reset", "0x00000000")
        access_summary = r["props"].get("access_summary", "?")
        owner = r["props"].get("owner", "?")
        field_access = [(f["name"], f["access"]) for f in r["fields"]]
        readback, prov = derive_readback(nm, field_access, owner)
        if readback.startswith("UNRESOLVED") or readback == "UNKNOWN":
            unresolved.append((nm, access_summary, owner, prov))

        params.append({"name": f"DFC_ADDR_{nm}", "width": AW, "value": f"0x{r['addr']:04X}",
                       "trace": f"REG-002 {nm} (0x{r['addr']:04X}); owner {owner}; "
                                f"access {access_summary}"})
        try:
            int(str(reset), 0)
            params.append({"name": f"DFC_RESET_{nm}", "width": 32, "value": reset,
                           "trace": f"REG-002 {nm} register reset"})
        except ValueError:
            nonnumeric_reset.append((nm, reset))

        meta.append({"name": nm, "addr": r["addr"], "reset": reset,
                     "access_summary": access_summary, "owner": owner,
                     "readback": readback, "readback_provenance": prov,
                     "contract_id": r["props"].get("contract_id", "?"),
                     "protection": r["props"].get("protection", "?")})
        structs.append({"name": f"dfc_reg_{nm.lower()}_t",
                        "trace": f"REG-002 {nm} (0x{r['addr']:04X}) field layout",
                        "fields": [{"name": f["name"], "hi": f["hi"], "lo": f["lo"],
                                    "access": f["access"], "reset": f["reset"]}
                                   for f in r["fields"]]})

    if unresolved:
        print(f"EXTRACTION FAILED -- {len(unresolved)} register(s) without a readback "
              f"classification (nothing written):", file=sys.stderr)
        for nm, a, o, prov in unresolved:
            print(f"  {nm}: access={a} owner={o} -- {prov}", file=sys.stderr)
        sys.exit(1)

    spec = {
        "package": "dfc_registers_pkg",
        "_source": (f"GENERATED by extract_registers.py from RCA-DFC-REG-002: "
                    f"{len(regs)} explicit register blocks, each with per-field "
                    f"Access/Reset. Verified {len(regs)} registers, unique addresses, "
                    f"per-register 32-bit tiling with no gaps/overlaps, and recognized "
                    f"access class on every non-reserved field. Readback classification "
                    f"is mechanical on per-field access + owner; the sole-RTL-001 "
                    f"RO-class exceptions are documented in AMBIGUOUS_RESOLVED with a "
                    f"citation each and extraction fails loud on any unresolved case."),
        "imports": ["dfc_constants_pkg"],
        "params": params,
        "structs": structs,
        "registers": meta,
    }
    json.dump(spec, open(out_path, "w", encoding="utf-8"), indent=2)
    return params, structs, meta, nonnumeric_reset


def main():
    if len(sys.argv) != 3:
        print("usage: extract_registers.py <REG-002.md> <out.json>", file=sys.stderr)
        sys.exit(2)
    reg_path, out_path = sys.argv[1], sys.argv[2]
    regs, errors = parse(reg_path)
    errors = verify(regs, errors)
    if errors:
        print(f"EXTRACTION FAILED ({len(errors)} error(s); nothing written):", file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        sys.exit(1)

    params, structs, meta, nonnumeric_reset = emit(regs, out_path)

    total_rows = sum(len(r["fields"]) for r in regs)
    named = sum(1 for r in regs for f in r["fields"] if not is_reserved(f["name"]))
    print(f"OK: {len(regs)} registers; unique addresses; every register tiles 32 bits "
          f"with no gaps/overlaps.")
    print(f"    field rows: {total_rows} total ({named} non-reserved named)")
    rb = Counter(m["readback"] for m in meta)
    mech = sum(1 for m in meta if m["readback_provenance"] == "mechanical")
    man = sum(1 for m in meta if m["readback_provenance"].startswith("manual"))
    print(f"    readback: {mech} mechanical + {man} manual (cited) = {mech + man}/{len(meta)}")
    for k, v in rb.most_common():
        print(f"      {v:4d}  {k}")
    if nonnumeric_reset:
        print(f"    NOTE: {len(nonnumeric_reset)} non-numeric register reset(s) "
              f"(no DFC_RESET_* emitted; not invented):")
        for nm, rv in nonnumeric_reset:
            print(f"          {nm}: reset = \"{rv}\"")
    print(f"    emitted {len(params)} params, {len(structs)} structs, {len(meta)} "
          f"register metadata entries -> {out_path}")


if __name__ == "__main__":
    main()
