#!/usr/bin/env python3
"""
check_coverage.py -- register/field coverage cross-reference.

HONESTY NOTE on scope: this is NOT a substitute for real simulation
coverage (line/toggle/FSM/functional coverage from a vendor tool or
Verilator --coverage). No such tool's coverage database exists in this
project. What this script actually does is much narrower and fully
mechanical: for each register in dfc_registers_pkg.json, it checks whether
that register's DFC_ADDR_<NAME> identifier appears anywhere in the
verification/testbench source tree. That is a textual reference-count
proxy for "this register is touched by some test," not proof that the
test exercises every legal/illegal value, access-class boundary, or
simultaneous-condition case VP-002 SS13 (VP-REG-001 through 018) actually
requires. A register showing as "referenced" here has AT MOST been read or
written once by some test; it may still be almost entirely unverified.

Use this to find registers with ZERO test references (a real, unambiguous
gap) -- do not read a nonzero count as "covered."

Usage: scripts/check_coverage.py [--registers path] [--testdir path]
"""
import argparse
import json
import re
import sys
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--registers", default="tools/pkggen/dfc_registers_pkg.json")
    ap.add_argument("--testdir", default="verification/testbench")
    ap.add_argument("--fail-under", type=float, default=None,
                     help="Exit nonzero if referenced-register percentage "
                          "falls below this threshold (0-100). Optional; "
                          "with no threshold, this script only reports.")
    args = ap.parse_args()

    reg_path = Path(args.registers)
    if not reg_path.exists():
        print(f"check_coverage.py: {reg_path} not found.", file=sys.stderr)
        print("  Run tools/pkggen/extract_registers.py first, or pass "
              "--registers.", file=sys.stderr)
        sys.exit(2)

    test_dir = Path(args.testdir)
    test_files = list(test_dir.rglob("*.sv")) if test_dir.exists() else []
    if not test_files:
        print(f"check_coverage.py: no .sv files found under {test_dir}.",
              file=sys.stderr)
        sys.exit(2)

    corpus = ""
    for f in test_files:
        try:
            corpus += f.read_text()
        except (UnicodeDecodeError, OSError) as e:
            print(f"check_coverage.py: WARNING could not read {f}: {e}",
                  file=sys.stderr)

    regs = json.load(open(reg_path))["registers"]

    referenced, unreferenced = [], []
    for r in regs:
        ident = f"DFC_ADDR_{r['name']}"
        # word-boundary match so e.g. DFC_ADDR_SYS_CONTROL doesn't false-
        # positive match on a hypothetical DFC_ADDR_SYS_CONTROL_EXT
        pattern = re.compile(r"\b" + re.escape(ident) + r"\b")
        count = len(pattern.findall(corpus))
        if count > 0:
            referenced.append((r["name"], count))
        else:
            unreferenced.append(r["name"])

    total = len(regs)
    pct = 100.0 * len(referenced) / total if total else 0.0

    print(f"check_coverage.py: {len(referenced)}/{total} registers "
          f"({pct:.1f}%) referenced at least once across "
          f"{len(test_files)} testbench file(s) under {test_dir}")
    print("(reminder: 'referenced' is a textual proxy, not verification "
          "coverage -- see file header)")
    print()

    if unreferenced:
        print(f"UNREFERENCED ({len(unreferenced)}) -- zero test touches this "
              f"register at all:")
        for name in unreferenced:
            print(f"  {name}")
    else:
        print("No fully-unreferenced registers.")

    if args.fail_under is not None and pct < args.fail_under:
        print(f"\ncheck_coverage.py: {pct:.1f}% is below --fail-under "
              f"{args.fail_under}%", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
