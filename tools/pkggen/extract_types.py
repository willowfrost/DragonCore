#!/usr/bin/env python3
"""
extract_types.py -- extractor for dfc_types_pkg.json, built fresh against RCA-DFC-ARCH-002.

Source: ARCH-002 Appendix B - Shared Packed Types.

Appendix B contains 54 struct headers in two families:
  * 5 simple records/requests (B.1-B.4, dfc_safety_response_req_t) using either
    "Absolute bits|Member|Width" or "Bits|Member|W|Contract" tables.
  * 49 rich control/status structs (B.5.1 dfc_rtl001_status_t, then
    dfc_rtl002_control_t/status_t .. dfc_rtl024_control_t/status_t = 1 + 23*2,
    PLUS 2 more added for RTL-017's ARINC RX adapter --
    dfc_rtl024_arinc_rx_adapter_control_t/status_t. This is the first
    instance of a rich struct pair that ISN'T one of the "one control_t/
    status_t per RTL-0NN module" set: ARCH-BUS-001's digital receive
    adapter is a real, hand-authored internal RTL-024 subblock (same
    "internal subblock, not a separate RTL-0NN module" status as the
    shared-buffer service), not a module with its own Appendix-A port row,
    but it still needs its own reggen-consumable control/status struct --
    reggen.py v5 requires a field-map's control_registers to cover its
    consumer struct's ENTIRE declared width, which made keeping ARX_CONTROL's
    5 real fields inside the general-purpose 278-bit dfc_rtl024_control_t
    impractical (that struct also carries ~270 unrelated host/test/clock-
    reset/buffer-clear fields no single field-map should need to map in one
    pass). The formula is no longer purely "1 + 23*2" and EXPECTED_RICH_
    STRUCTS below is no longer silently assumed to stay at 47 forever --
    update it deliberately, with a disclosed reason, whenever a genuinely
    new rich struct is added outside the per-module set, exactly as this
    one was) using a uniform "Bits|Member|W|Signedness|Reset|Semantic"
    table. This is this extractor's primary target; the 5 simple records
    are captured too for completeness since they cost nothing extra to
    parse with the same engine.

Header format is inconsistent cosmetically (struct name sometimes backtick-
wrapped, sometimes not; some headers are ### and one is #### for B.5.1) but
uniform structurally: "#{3,4} [ID ]NAME_t — N bits" or a backtick-wrapped NAME_t.
Note the trailing word is always literally "bits" (plural), even for a
1-bit struct -- the header regex requires it literally; "1 bit" (singular)
will NOT match and silently merges that struct's table rows into whichever
struct was parsed immediately before it (confirmed via a real extraction
failure: "dfc_rtl024_arinc_rx_adapter_control_t: bit 0 overlap" was this
exact bug, from a "1 bit" heading instead of "1 bits").

VERIFICATION (fail-loud; nothing written on any failure):
  * exactly 49 rich-format (control/status) structs found
  * every struct's fields tile [0 .. declared_width-1] with no gaps/overlaps
  * declared width in the header matches the max bit + 1 from the field table
  * all member names within a struct are unique
"""
import re, sys, json

EXPECTED_RICH_STRUCTS = 49  # 47 (1 + 23*2 per-module) + 2 (RTL-024's ARINC
                            # RX adapter control_t/status_t -- see this
                            # file's own header for why the formula grew)

HDR = re.compile(r'^#{3,4}\s+(?:B\.\d+(?:\.\d+)?\s+)?`?([a-z][a-z0-9_]*_t)`?\s+\u2014\s+(\d+)\s+bits\s*$')
RICH_HEADER = re.compile(r'^\|\s*\*\*Bits\*\*\s*\|\s*\*\*Member\*\*\s*\|\s*\*\*W\*\*\s*\|\s*\*\*Signedness\*\*\s*\|\s*\*\*Reset\*\*\s*\|\s*\*\*Semantic\*\*\s*\|')
SIMPLE_HEADER = re.compile(r'^\|\s*\*\*(?:Absolute )?[Bb]its\*\*\s*\|\s*\*\*Member\*\*\s*\|\s*\*\*W(?:idth)?\*\*\s*\|')
SEP_ROW = re.compile(r'^\|[\s:\-|]+\|$')
BITSPEC = re.compile(r'^\*{0,2}(\d+)(?::(\d+))?\*{0,2}$')

# ---- ARCH-002 SS4.1 "Primary Operating State" enum table (dfc_operating_state_t)
# -- this lives in the main body, NOT Appendix B, so it needs its own section
# scan independent of the Appendix-B-only struct scan above. Missed entirely by
# the original extractor (confirmed: zero "typedef enum" in any generated
# package across a real run) since Appendix B's struct-table shape
# (Bits|Member|W|Signedness|Reset|Semantic) is structurally different from
# this table's shape (Contract ID|State|Encoding|Entry and exit contract).
ENUM_SECTION_HDR = re.compile(r'^###\s+4\.1\s+Primary Operating State\s*$')
ENUM_TABLE_HEADER = re.compile(
    r'^\|\s*Contract ID\s*\|\s*State\s*\|\s*Encoding\s*\|\s*Entry and exit contract\s*\|')
ENCODING_RE = re.compile(r"^(\d+)'b([01]+)$")
EXPECTED_STATE_NAMES = ["RESET_ACTIVE", "STARTUP", "NORMAL", "DEGRADED", "FAULTED", "TEST_DEBUG"]


def cells(line):
    if not line.startswith("|"):
        return None
    return [c.strip().strip("*").strip("`").strip() for c in line.strip().strip("|").split("|")]


def parse(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    structs, errors = [], []
    # scope to Appendix B only
    start = end = None
    for idx, ln in enumerate(lines):
        if re.match(r'^# Appendix B\b', ln):
            start = idx
        elif start is not None and re.match(r'^# Appendix C\b', ln):
            end = idx
            break
    if start is None:
        errors.append("Appendix B header not found")
        return [], errors
    if end is None:
        end = len(lines)
    body = lines[start:end]

    i = 0
    while i < len(body):
        h = HDR.match(body[i])
        if not h:
            i += 1
            continue
        name, decl_width = h.group(1), int(h.group(2))
        fields, kind = [], None
        j = i + 1
        while j < len(body):
            ln = body[j]
            if HDR.match(ln) or ln.startswith("## ") or ln.startswith("# "):
                break
            if RICH_HEADER.match(ln):
                kind = "rich"
                j += 1
                continue
            if SIMPLE_HEADER.match(ln):
                kind = "simple"
                j += 1
                continue
            if SEP_ROW.match(ln):
                j += 1
                continue
            c = cells(ln)
            if c and kind and BITSPEC.match(c[0]):
                m = BITSPEC.match(c[0])
                hi = int(m.group(1))
                lo = int(m.group(2)) if m.group(2) else hi
                member, width = c[1], c[2]
                entry = {"name": member, "hi": hi, "lo": lo, "width": int(width)}
                if kind == "rich":
                    entry["signed"] = (c[3].strip().lower() == "signed")
                    entry["reset"] = c[4]
                    entry["semantic"] = c[5]
                elif kind == "simple" and len(c) >= 4:
                    entry["contract"] = c[3]
                fields.append(entry)
            j += 1
        if fields:
            structs.append({"name": name, "decl_width": decl_width, "kind": kind, "fields": fields})
        else:
            errors.append(f"{name}: header matched but no field rows parsed")
        i = j
    return structs, errors


def parse_operating_state(lines):
    """Extracts dfc_operating_state_t from ARCH-002 SS4.1 -- scans the WHOLE
    document (not Appendix-B-scoped) since this table lives in the main body.
    Returns (values, errors); values is a list of
    {"name", "width", "value", "contract_id"} dicts for the six named states
    (Reserved's row is confirmed present but intentionally excluded from the
    emitted enum -- those two encodings must never be a legal enum literal,
    per ARCH-STATE-007's "never generated" contract)."""
    errors = []
    section_idx = None
    for idx, ln in enumerate(lines):
        if ENUM_SECTION_HDR.match(ln.strip()):
            section_idx = idx
            break
    if section_idx is None:
        errors.append("ARCH-002 SS4.1 'Primary Operating State' section not found")
        return None, errors

    j = section_idx + 1
    header_idx = None
    while j < len(lines):
        if ENUM_TABLE_HEADER.match(lines[j]):
            header_idx = j
            break
        if lines[j].startswith("### ") or lines[j].startswith("## "):
            break
        j += 1
    if header_idx is None:
        errors.append("ARCH-002 SS4.1 operating-state table header not found")
        return None, errors

    j = header_idx + 1
    if j < len(lines) and SEP_ROW.match(lines[j]):
        j += 1

    values = []
    reserved_seen = False
    while j < len(lines) and lines[j].startswith("|"):
        c = cells(lines[j])
        if c and len(c) >= 3:
            contract_id, state, encoding = c[0], c[1], c[2]
            if state == "Reserved":
                reserved_seen = True
                j += 1
                continue
            m = ENCODING_RE.match(encoding)
            if not m:
                errors.append(f"operating-state row '{state}': encoding '{encoding}' not parseable "
                              f"as N'bBITS")
                j += 1
                continue
            width, bits = int(m.group(1)), m.group(2)
            if len(bits) != width:
                errors.append(f"operating-state row '{state}': encoding '{encoding}' bit-string "
                              f"length doesn't match declared width {width}")
            values.append({"name": state, "width": width, "value": f"{width}'b{bits}",
                           "contract_id": contract_id})
        j += 1

    if not values:
        errors.append("ARCH-002 SS4.1 operating-state table: no named-state rows parsed")
        return None, errors
    if not reserved_seen:
        errors.append("ARCH-002 SS4.1 operating-state table: no 'Reserved' row found -- expected, "
                      "confirms which encodings are deliberately omitted from the enum")

    names = [v["name"] for v in values]
    if names != EXPECTED_STATE_NAMES:
        errors.append(f"operating-state names {names} != expected {EXPECTED_STATE_NAMES}")
    widths = {v["width"] for v in values}
    if widths != {3}:
        errors.append(f"operating-state: expected all-3-bit encodings, got widths {sorted(widths)}")
    encodings = [v["value"] for v in values]
    if len(set(encodings)) != len(encodings):
        errors.append(f"operating-state: duplicate encoding among {encodings}")

    return values, errors


def verify(structs, errors):
    rich = [s for s in structs if s["kind"] == "rich"]
    if len(rich) != EXPECTED_RICH_STRUCTS:
        errors.append(f"rich (control/status) struct count {len(rich)} != {EXPECTED_RICH_STRUCTS}")
    for s in structs:
        w = s["decl_width"]
        covered = [False] * w
        names = set()
        for f in s["fields"]:
            if f["name"] in names:
                errors.append(f"{s['name']}: duplicate member '{f['name']}'")
            names.add(f["name"])
            if f["hi"] - f["lo"] + 1 != f["width"]:
                errors.append(f"{s['name']}.{f['name']}: bit range [{f['hi']}:{f['lo']}] "
                              f"doesn't match declared width {f['width']}")
            for b in range(f["lo"], f["hi"] + 1):
                if b >= w:
                    errors.append(f"{s['name']}.{f['name']}: bit {b} >= declared width {w}")
                    continue
                if covered[b]:
                    errors.append(f"{s['name']}: bit {b} overlap at '{f['name']}'")
                covered[b] = True
        gaps = [b for b in range(w) if not covered[b]]
        if gaps:
            errors.append(f"{s['name']} (declared {w} bits): {len(gaps)} uncovered bit(s) "
                          f"{gaps[:6]}{'...' if len(gaps) > 6 else ''}")
    return errors


def emit(structs, enum_values, out_path):
    out_structs = []
    for s in structs:
        out_structs.append({
            "name": s["name"],
            "trace": f"ARCH-002 Appendix B {s['name']} ({s['decl_width']} bits, {s['kind']} format)",
            "width": s["decl_width"],
            "fields": [
                {"name": f["name"], "hi": f["hi"], "lo": f["lo"], "width": f["width"],
                 **({"signed": f["signed"], "reset": f["reset"], "semantic": f["semantic"]}
                    if s["kind"] == "rich" else
                    ({"contract": f["contract"]} if "contract" in f else {}))}
                for f in s["fields"]
            ],
        })
    out_enums = [{
        "name": "dfc_operating_state_t",
        "trace": "ARCH-002 SS4.1 Primary Operating State (ARCH-STATE-001 through 006; "
                 "ARCH-STATE-007's two Reserved encodings are deliberately omitted -- they "
                 "must never be legal enum literals)",
        "width": 3,
        "values": [{"name": v["name"], "value": v["value"], "contract_id": v["contract_id"]}
                   for v in enum_values],
    }]
    spec = {
        "package": "dfc_types_pkg",
        "_source": (f"GENERATED by extract_types.py from RCA-DFC-ARCH-002 Appendix B and SS4.1. "
                    f"{len(structs)} structs total ({sum(1 for s in structs if s['kind']=='rich')} "
                    f"rich control/status structs verified against the "
                    f"{EXPECTED_RICH_STRUCTS}-struct expectation, plus shared records/requests), "
                    f"plus 1 shared enum (dfc_operating_state_t, SS4.1). "
                    f"Every struct verified: contiguous bit tiling with no gaps/overlaps, "
                    f"declared width matches max bit + 1, unique member names, and each field's "
                    f"bit range matches its declared width. The enum is verified: exactly the six "
                    f"expected named states, all 3-bit encodings, no duplicate encodings, and a "
                    f"Reserved row confirmed present in source (whose two encodings are excluded "
                    f"from the emitted enum, not silently dropped)."),
        "imports": ["dfc_constants_pkg"],
        "structs": out_structs,
        "enums": out_enums,
    }
    json.dump(spec, open(out_path, "w", encoding="utf-8"), indent=2)


def main():
    if len(sys.argv) != 3:
        print("usage: extract_types.py <ARCH-002.md> <out.json>", file=sys.stderr)
        sys.exit(2)
    arch_path, out_path = sys.argv[1], sys.argv[2]
    lines = open(arch_path, encoding="utf-8").read().split("\n")

    structs, errors = parse(arch_path)
    errors = verify(structs, errors)

    enum_values, enum_errors = parse_operating_state(lines)
    errors += enum_errors

    if errors:
        print(f"EXTRACTION FAILED ({len(errors)} error(s); nothing written):", file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        sys.exit(1)
    emit(structs, enum_values, out_path)
    rich = [s for s in structs if s["kind"] == "rich"]
    simple = [s for s in structs if s["kind"] == "simple"]
    total_fields = sum(len(s["fields"]) for s in structs)
    print(f"OK: {len(structs)} structs ({len(rich)} rich control/status + {len(simple)} simple "
          f"records); every struct tiles its declared width with no gaps/overlaps; "
          f"{total_fields} total fields. Plus 1 enum (dfc_operating_state_t, "
          f"{len(enum_values)} named states).")
    print(f"    emitted -> {out_path}")


if __name__ == "__main__":
    main()
