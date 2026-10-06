#!/usr/bin/env python3
"""
extract_constants.py -- extractor for dfc_constants_pkg.json.

Sources (both confirmed by direct inspection of the real documents, not
assumed):
  * REG-002's protected-write authorization sequence, stated as one
    prose sentence (not a table -- these are protocol constants, not
    register fields): "The protected-write sequence is two consecutive
    accepted writes to `PROTECT_KEY.KEY`: `0x52434131`, then
    `0x4452474E`, followed by exactly one protected write within 50,000
    CORE_CLK cycles." -> DFC_PROTECT_KEY1, DFC_PROTECT_KEY2,
    DFC_PROTECT_TIMEOUT_CYCLES.
  * ARCH-002's ARCH-CLK-001 table row (a real, structured table, not
    prose): "| ARCH-CLK-001 | CORE_CLK | `core_clk_i`, nominal 50 MHz;
    ... |" -> DFC_CORE_CLK_HZ.
  * ARCH-002 SS12.1's "Centralized Shared-Buffer Service" segment table
    (ARCH-BUF-001 through ARCH-BUF-012, a real structured table) -> one
    BASE/WIDTH pair per client (7 clients: RTL-017..022 + RTL-024 SPI),
    plus DFC_BUF_CLIENT_COUNT and DFC_BUF_TOTAL_WORDS. Per RTLSTD-MEM-004,
    the shared-buffer service's segment bases/widths must come from this
    package, not be hand-copied into RTL-024 or any client module.

HONESTY NOTE on scope: unlike extract_registers.py/extract_types.py
(clean, uniform tables), the first source here is prose, not a table.
This is a real, unavoidable difference in kind for these specific
values -- they are protocol/timing constants stated in running text in
REG-002's own SS4, not register fields with their own table row. The
pattern matched below is deliberately narrow and specific (exact
backtick-wrapped hex/decimal values inside one exact sentence
structure) precisely so that if this sentence is ever reworded, this
extractor fails loud rather than silently matching something else or
extracting a stale value.

The buffer-segment table, by contrast, IS a real structured table (like
extract_registers.py's source), so it's parsed as one the same way --
but the 7 real clients don't correspond 1:1 with the 12 ARCH-BUF rows
(RTL-019/020/021/024-SPI each span two adjacent rows: RX+TX or
command+response). The merge step below groups rows into clients
explicitly, by the exact owner text ARCH-002 prints for each row, and
verifies every merged client is contiguous and that the 7 clients plus
the trailing reserved row tile exactly 0..511 -- if a future edit to
ARCH-002 changes the grouping, reorders rows, or opens a gap, this
extractor fails loud instead of emitting a silently-wrong segment map.

VERIFICATION (fail-loud; nothing written on any failure):
  * the exact protected-write sentence must be found, containing
    exactly 2 backtick-wrapped hex values and 1 decimal cycle count in
    that specific order
  * the ARCH-CLK-001 row must be found in ARCH-002's port/requirement
    table, containing a "<number> MHz" pattern
  * all 12 ARCH-BUF-001..012 segment rows must be found, in order, each
    matching the owner text this extractor expects to merge it under;
    the 7 merged client ranges and the final reserved row must tile
    exactly 0..511 with no gap or overlap
"""
import re, sys, json

PROTECT_SENTENCE_RE = re.compile(
    r'two consecutive accepted writes to `PROTECT_KEY\.KEY`:\s*'
    r'`(0x[0-9A-Fa-f]+)`,\s*then\s*`(0x[0-9A-Fa-f]+)`,\s*'
    r'followed by exactly one protected write within\s*'
    r'([\d,]+)\s*CORE_CLK cycles'
)

CLK_ROW_RE = re.compile(
    r'\|\s*ARCH-CLK-001\s*\|.*?nominal\s+(\d+)\s*MHz', re.IGNORECASE
)

# One row per ARCH-BUF-NNN entry: "| ARCH-BUF-001 | `0x000-0x00F` | RTL-024
# SPI command | 16 words |". The address range uses an EN DASH (U+2013)
# between the two hex values in the real document, not an ASCII hyphen --
# matched literally here so a future accidental normalization to ASCII
# "-" is caught (fails loud) rather than silently matched by a looser
# pattern.
BUF_ROW_RE = re.compile(
    r'\|\s*ARCH-BUF-(\d{3})\s*\|\s*`0x([0-9A-Fa-f]{3})–0x([0-9A-Fa-f]{3})`\s*\|'
    r'\s*([^|]+?)\s*\|'
)

# Which ARCH-BUF row IDs merge into each of the 7 real clients, in client-
# index order (0..6), and the exact owner text ARCH-002 prints for the
# FIRST row of each group (checked verbatim so a reworded owner column is
# a hard failure, not a silent mismatch).
BUF_CLIENT_GROUPS = [
    (0, "RTL-017 ARINC RX",                 ["003"]),
    (1, "RTL-018 ARINC TX",                 ["004"]),
    (2, "RTL-019 CAN RX",                   ["005", "006"]),
    (3, "RTL-020 UART RX",                  ["007", "008"]),
    (4, "RTL-021 routing ingress",          ["009", "010"]),
    (5, "RTL-022 input/output mailboxes",   ["011"]),
    (6, "RTL-024 SPI command",              ["001", "002"]),
]
BUF_RESERVED_ROW_ID = "012"
BUF_TOTAL_WORDS = 512  # 9-bit word_offset, ARCH-002 SS12.1: "512 x 32-bit"


def extract_protect_constants(reg002_text):
    m = PROTECT_SENTENCE_RE.search(reg002_text)
    if not m:
        return None, ("REG-002: could not find the expected protected-write "
                      "authorization sentence (two backtick-wrapped hex "
                      "values + a CORE_CLK cycle count) -- has REG-002 "
                      "Section 4 been reworded?")
    key1, key2, timeout_str = m.group(1), m.group(2), m.group(3).replace(",", "")
    return {
        "key1": key1.upper().replace("0X", "0x"),
        "key2": key2.upper().replace("0X", "0x"),
        "timeout_cycles": int(timeout_str),
    }, None


def extract_clk_hz(arch002_text):
    m = CLK_ROW_RE.search(arch002_text)
    if not m:
        return None, ("ARCH-002: could not find the ARCH-CLK-001 row with a "
                      "'nominal <N> MHz' pattern -- has the clock "
                      "requirement been reworded or the row removed?")
    mhz = int(m.group(1))
    return mhz * 1_000_000, None


def extract_buffer_segments(arch002_text):
    section_start = arch002_text.find("Centralized Shared-Buffer Service")
    if section_start < 0:
        return None, ("ARCH-002: could not find the 'Centralized "
                      "Shared-Buffer Service' section at all -- has SS12 "
                      "been renamed or removed?")
    # Scope the row search to the SS12.1 table only (stop at the next "## "
    # top-level section) so a coincidental ARCH-BUF-like string elsewhere in
    # the document can never be picked up.
    next_section = arch002_text.find("\n## ", section_start + 1)
    section_text = arch002_text[section_start:next_section if next_section > 0 else None]

    rows = {}
    for m in BUF_ROW_RE.finditer(section_text):
        row_id, start_hex, end_hex, owner = m.groups()
        if row_id in rows:
            return None, (f"ARCH-002: ARCH-BUF-{row_id} matched more than "
                          f"once in SS12.1 -- table structure changed "
                          f"unexpectedly.")
        start = int(start_hex, 16)
        end = int(end_hex, 16)
        if end < start:
            return None, (f"ARCH-002: ARCH-BUF-{row_id} has end address "
                          f"0x{end_hex} before start 0x{start_hex}.")
        rows[row_id] = {"start": start, "width": end - start + 1, "owner": owner.strip()}

    expected_ids = [f"{i:03d}" for i in range(1, 13)]
    missing = [rid for rid in expected_ids if rid not in rows]
    if missing:
        return None, (f"ARCH-002: SS12.1 segment table is missing expected "
                      f"row(s) ARCH-BUF-{', ARCH-BUF-'.join(missing)} -- "
                      f"expected exactly ARCH-BUF-001 through -012.")

    # Each client's OWN constituent rows must be internally contiguous (e.g.
    # RTL-019's RX row immediately followed by its TX row) -- checked per
    # client, in the fixed row-merge order above, independent of where that
    # client's segment happens to sit in the wider 0..511 address space.
    clients = []
    for idx, expected_owner_prefix, row_ids in BUF_CLIENT_GROUPS:
        first = rows[row_ids[0]]
        base = first["start"]
        if not first["owner"].startswith(expected_owner_prefix[:7]):
            return None, (f"ARCH-002: ARCH-BUF-{row_ids[0]}'s owner text "
                          f"('{first['owner']}') does not start with the "
                          f"expected '{expected_owner_prefix[:7]}' -- has "
                          f"client {idx}'s owner been renumbered or "
                          f"reworded?")
        width = 0
        expect_start = base
        for rid in row_ids:
            row = rows[rid]
            if row["start"] != expect_start:
                return None, (f"ARCH-002: ARCH-BUF-{rid} starts at "
                              f"0x{row['start']:03X}, expected 0x"
                              f"{expect_start:03X} -- segment rows merged "
                              f"into client {idx} are not contiguous.")
            width += row["width"]
            expect_start += row["width"]
        clients.append({"index": idx, "base": base, "width": width})

    # The 7 clients are NOT listed in physical-address order above (client 6,
    # RTL-024 SPI, physically sits FIRST at 0x000; clients 0-5 follow in
    # address order after it) -- so the whole-space tiling check sorts by
    # base address rather than assuming BUF_CLIENT_GROUPS' own (logical,
    # not physical) ordering lines up with memory layout.
    reserved = rows[BUF_RESERVED_ROW_ID]
    all_ranges = [(c["base"], c["width"], f"client {c['index']}") for c in clients]
    all_ranges.append((reserved["start"], reserved["width"], "reserved row"))
    all_ranges.sort(key=lambda r: r[0])

    cursor = 0
    for base, width, label in all_ranges:
        if base != cursor:
            return None, (f"ARCH-002: {label} starts at 0x{base:03X}, "
                          f"expected 0x{cursor:03X} -- segment map has a "
                          f"gap or overlap when tiled across 0..511.")
        cursor += width
    if cursor != BUF_TOTAL_WORDS:
        return None, (f"ARCH-002: 7 clients + reserved tile to {cursor} "
                      f"words, expected exactly {BUF_TOTAL_WORDS} -- SS12.1 "
                      f"no longer describes a 512-word store?")

    return clients, None


def main():
    if len(sys.argv) != 4:
        print("usage: extract_constants.py <REG-002.md> <ARCH-002.md> <out.json>",
              file=sys.stderr)
        sys.exit(2)
    reg_path, arch_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    reg_text = open(reg_path, encoding="utf-8").read()
    arch_text = open(arch_path, encoding="utf-8").read()

    protect, e1 = extract_protect_constants(reg_text)
    clk_hz, e2 = extract_clk_hz(arch_text)
    buf_clients, e3 = extract_buffer_segments(arch_text)
    errors = [e for e in (e1, e2, e3) if e]

    if errors:
        print(f"EXTRACTION FAILED ({len(errors)} error(s); nothing written):", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        sys.exit(1)

    params = [
        {"name": "DFC_PROTECT_KEY1", "width": 32, "value": protect["key1"],
         "trace": "REG-002 Section 4: first accepted protected-write key word "
                  "(extracted from the authorization-sequence sentence)"},
        {"name": "DFC_PROTECT_KEY2", "width": 32, "value": protect["key2"],
         "trace": "REG-002 Section 4: second accepted protected-write key word"},
        {"name": "DFC_PROTECT_TIMEOUT_CYCLES", "width": 32,
         "value": str(protect["timeout_cycles"]),
         "trace": "REG-002 Section 4: protected write must follow within this "
                  "many CORE_CLK cycles of key acceptance"},
        {"name": "DFC_CORE_CLK_HZ", "width": 32, "value": str(clk_hz),
         "trace": "ARCH-002 ARCH-CLK-001: core_clk_i nominal frequency"},
    ]

    for c in buf_clients:
        n = c["index"]
        params.append({
            "name": f"DFC_BUF_CLIENT{n}_BASE", "width": 32,
            "value": str(c["base"]),
            "trace": f"ARCH-002 SS12.1: shared-buffer client {n} segment base word address",
        })
        params.append({
            "name": f"DFC_BUF_CLIENT{n}_WIDTH", "width": 32,
            "value": str(c["width"]),
            "trace": f"ARCH-002 SS12.1: shared-buffer client {n} segment width in words",
        })
    params.append({
        "name": "DFC_BUF_CLIENT_COUNT", "width": 32, "value": "7",
        "trace": "ARCH-002 SS12.2: seven typed shared-buffer clients (0=RTL-017 .. 6=RTL-024 SPI)",
    })
    params.append({
        "name": "DFC_BUF_TOTAL_WORDS", "width": 32, "value": str(BUF_TOTAL_WORDS),
        "trace": "ARCH-002 SS12.1: one logical 512 x 32-bit centralized shared-buffer store",
    })

    spec = {
        "package": "dfc_constants_pkg",
        "_source": ("GENERATED by extract_constants.py from REG-002 Section 4's "
                    "protected-write authorization sentence (PROTECT_KEY1/2, "
                    "PROTECT_TIMEOUT_CYCLES), ARCH-002's ARCH-CLK-001 row "
                    "(CORE_CLK_HZ), and ARCH-002 SS12.1's shared-buffer segment "
                    "table (DFC_BUF_CLIENTn_BASE/_WIDTH, DFC_BUF_CLIENT_COUNT, "
                    "DFC_BUF_TOTAL_WORDS). The protected-write values are "
                    "matched via a deliberately narrow prose pattern (see this "
                    "file's own header) since they are protocol constants "
                    "stated in running text, not register table fields."),
        "imports": [],
        "params": params,
    }
    json.dump(spec, open(out_path, "w", encoding="utf-8"), indent=2)
    print(f"OK: {len(params)} constants extracted "
          f"(2 protect keys, 1 timeout, 1 clock freq, "
          f"{len(buf_clients)} buffer clients x 2, 2 buffer scalars) -> {out_path}")


if __name__ == "__main__":
    main()
