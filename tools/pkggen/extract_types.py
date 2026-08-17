#!/usr/bin/env python3
"""
extract_types.py -- extractor for dfc_types_pkg.json, built fresh against RCA-DFC-ARCH-002.

Source: ARCH-002 Appendix B - Shared Packed Types.

Appendix B contains 52 struct headers in two families:
  * 5 simple records/requests (B.1-B.4, dfc_safety_response_req_t) using either
    "Absolute bits|Member|Width" or "Bits|Member|W|Contract" tables.
  * 47 rich control/status structs (B.5.1 dfc_rtl001_status_t, then
    dfc_rtl002_control_t/status_t .. dfc_rtl024_control_t/status_t = 1 + 23*2)
    using a uniform "Bits|Member|W|Signedness|Reset|Semantic" table. This is
    the "~47 structs" scope named in the project brief, and is this
    extractor's primary target; the 5 simple records are captured too for
    completeness since they cost nothing extra to parse with the same engine.

Header format is inconsistent cosmetically (struct name sometimes backtick-
wrapped, sometimes not; some headers are ### and one is #### for B.5.1) but
uniform structurally: "#{3,4} [ID ]NAME_t — N bits" or a backtick-wrapped NAME_t.

VERIFICATION (fail-loud; nothing written on any failure):
  * exactly 47 rich-format (control/status) structs found
  * every struct's fields tile [0 .. declared_width-1] with no gaps/overlaps
  * declared width in the header matches the max bit + 1 from the field table
  * all member names within a struct are unique
"""
import re, sys, json

EXPECTED_RICH_STRUCTS = 47

HDR = re.compile(r'^#{3,4}\s+(?:B\.\d+(?:\.\d+)?\s+)?`?([a-z][a-z0-9_]*_t)`?\s+\u2014\s+(\d+)\s+bits\s*$')
RICH_HEADER = re.compile(r'^\|\s*\*\*Bits\*\*\s*\|\s*\*\*Member\*\*\s*\|\s*\*\*W\*\*\s*\|\s*\*\*Signedness\*\*\s*\|\s*\*\*Reset\*\*\s*\|\s*\*\*Semantic\*\*\s*\|')
SIMPLE_HEADER = re.compile(r'^\|\s*\*\*(?:Absolute )?[Bb]its\*\*\s*\|\s*\*\*Member\*\*\s*\|\s*\*\*W(?:idth)?\*\*\s*\|')
SEP_ROW = re.compile(r'^\|[\s:\-|]+\|$')
BITSPEC = re.compile(r'^\*{0,2}(\d+)(?::(\d+))?\*{0,2}$')


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


def emit(structs, out_path):
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
    spec = {
        "package": "dfc_types_pkg",
        "_source": (f"GENERATED by extract_types.py from RCA-DFC-ARCH-002 Appendix B. "
                    f"{len(structs)} structs total ({sum(1 for s in structs if s['kind']=='rich')} "
                    f"rich control/status structs verified against the "
                    f"{EXPECTED_RICH_STRUCTS}-struct expectation, plus shared records/requests). "
                    f"Every struct verified: contiguous bit tiling with no gaps/overlaps, "
                    f"declared width matches max bit + 1, unique member names, and each field's "
                    f"bit range matches its declared width."),
        "imports": ["dfc_constants_pkg"],
        "structs": out_structs,
    }
    json.dump(spec, open(out_path, "w", encoding="utf-8"), indent=2)


def main():
    if len(sys.argv) != 3:
        print("usage: extract_types.py <ARCH-002.md> <out.json>", file=sys.stderr)
        sys.exit(2)
    arch_path, out_path = sys.argv[1], sys.argv[2]
    structs, errors = parse(arch_path)
    errors = verify(structs, errors)
    if errors:
        print(f"EXTRACTION FAILED ({len(errors)} error(s); nothing written):", file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        sys.exit(1)
    emit(structs, out_path)
    rich = [s for s in structs if s["kind"] == "rich"]
    simple = [s for s in structs if s["kind"] == "simple"]
    total_fields = sum(len(s["fields"]) for s in structs)
    print(f"OK: {len(structs)} structs ({len(rich)} rich control/status + {len(simple)} simple "
          f"records); every struct tiles its declared width with no gaps/overlaps; "
          f"{total_fields} total fields.")
    print(f"    emitted -> {out_path}")


if __name__ == "__main__":
    main()
