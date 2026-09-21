#!/usr/bin/env python3
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
"""Check permissive SELinux denials against stock's and this build's policy (2026-09-12).

For each denied permission in a logcat capture, a policy is compiled with
secilc plus a neverallow for exactly that permission. secilc reports the
neverallow as failed when an allow rule grants the permission and prints that
rule with its file and line, whichever way the rule reaches the types
(directly, through an attribute, from a macro). A failure is thus a permission
the policy allows. Both policies are checked, each as the CIL files init
compiles at boot:
  - stock, from the dump: plat_sepolicy.cil with the mapping for the vendor's
    platform version, system_ext, product, plat_pub_versioned, vendor, odm;
  - ours, the same files from out/target/product/pdx246.
A permission stock allows and ours does not is a rule to port; stock's rule
shows whether it comes through an attribute. One both allow was denied by a
constraint (MLS), not by a missing rule. One neither allows is denied on stock
as well.

Run from the tree root:
  python3 device/sony/pdx246/tools/selinux-stock-allows.py CAPTURE [--lines N]
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict

# The stock firmware dump (dumpyara); set PDX246_STOCK_DUMP to use another one.
DUMP = os.environ.get("PDX246_STOCK_DUMP", "")
if not DUMP:
    raise SystemExit("set PDX246_STOCK_DUMP to an extracted stock firmware dump")
OUT = "out/target/product/pdx246"
SECILC = "out/host/linux-x86/bin/secilc"
# Stock's names for the types hardware/sony/sepolicy spells differently (the
# inverse of RENAME in selinux-port-stock-rules.py).
STOCK_NAME = {"vendor_hal_idd_hwservice": "hal_idd_hwservice",
              "somc_wifi_idd_hal_service": "hal_somc_wifi_idd_default",
              "somc_wifi_idd_hal_service_exec": "hal_somc_wifi_idd_default_exec",
              "vendor_hal_nxpnfc_service": "nxpnfc_service"}
for _hal in ("idd", "miscta", "secd", "spc"):
    for _suffix in ("", "_client", "_server", "_default", "_default_exec"):
        STOCK_NAME[f"vendor_hal_{_hal}{_suffix}"] = f"hal_{_hal}{_suffix}"

DENIAL_RE = re.compile(r"avc: +denied +\{ ([^}]+) \} for .*?scontext=u:r:([\w.-]+):s0\S* "
                       r"tcontext=u:(?:object_)?r:([\w.-]+):s0\S* tclass=(\w+)")
FAILED_RE = re.compile(r"^neverallow check failed at (.+):(\d+)$")
ALLOW_AT_RE = re.compile(r"^\s+allow at (.+):(\d+)$")
SECTIONS = [("port", "stock allows, ours does not: rules to port (stock's rule below each)"),
            ("constraint", "ours allows as well: denied by a constraint such as MLS"),
            ("both", "stock does not allow either"),
            ("n/a", "not checkable against stock: type or permission unknown there")]


def policy_files(root):
    """The CIL files init compiles for the partitions under root."""
    def sel(part):
        return f"{root}/{part}/etc/selinux"
    with open(sel("vendor") + "/plat_sepolicy_vers.txt") as f:
        vers = f.read().strip()
    required = [sel("system") + "/plat_sepolicy.cil", f"{sel('system')}/mapping/{vers}.cil",
                sel("vendor") + "/plat_pub_versioned.cil", sel("vendor") + "/vendor_sepolicy.cil"]
    optional = [f"{sel('system')}/mapping/{vers}.compat.cil",
                sel("system_ext") + "/system_ext_sepolicy.cil",
                f"{sel('system_ext')}/mapping/{vers}.cil",
                f"{sel('system_ext')}/mapping/{vers}.compat.cil",
                sel("product") + "/product_sepolicy.cil",
                f"{sel('product')}/mapping/{vers}.cil",
                sel("odm") + "/odm_sepolicy.cil"]
    for f in required:
        if not os.path.exists(f):
            sys.exit(f"missing {f}")
    return vers, required + [f for f in optional if os.path.exists(f)]


def declarations(files):
    """Declared type and attribute names, and each class's permissions."""
    types, perms, commons, classcommon = set(), defaultdict(set), {}, {}
    for path in files:
        with open(path, errors="replace") as f:
            for line in f:
                if m := re.match(r"^\((?:type|typeattribute|typealias) (\S+)\)", line):
                    types.add(m.group(1))
                elif m := re.match(r"^\(class (\S+) \(([^()]*)\)\)", line):
                    perms[m.group(1)] |= set(m.group(2).split())
                elif m := re.match(r"^\(common (\S+) \(([^()]*)\)\)", line):
                    commons[m.group(1)] = set(m.group(2).split())
                elif m := re.match(r"^\(classcommon (\S+) (\S+)\)", line):
                    classcommon[m.group(1)] = m.group(2)
    for cls, common in classcommon.items():
        perms[cls] |= commons.get(common, set())
    return types, perms


def allowed(files, checks, workdir, name):
    """Map each check's index to the rules granting it (empty if none), or None
    when the policy lacks one of its names."""
    types, perms = declarations(files)
    result, lines, index_at = {}, [], {}
    for i, (src, tgt, cls, perm) in enumerate(checks):
        if src not in types or tgt not in types or perm not in perms.get(cls, ()):
            result[i] = None
            continue
        lines.append(f"(neverallow {src} {tgt} ({cls} ({perm})))")
        index_at[len(lines)] = i
        result[i] = []
    query = os.path.join(workdir, f"query-{name}.cil")
    with open(query, "w") as f:
        f.write("\n".join(lines) + "\n")
    proc = subprocess.run([SECILC, "-m", "-M", "true", "-G", "-c", "33",
                           "-o", os.path.join(workdir, name + ".bin"), "-f", os.devnull,
                           *files, query], capture_output=True, text=True)
    out = (proc.stdout + proc.stderr).splitlines()
    current, failures = None, 0
    for n, line in enumerate(out):
        if m := FAILED_RE.match(line):
            failures += 1
            current = index_at.get(int(m.group(2))) if m.group(1) == query else None
        elif (m := ALLOW_AT_RE.match(line)) and current is not None and n + 1 < len(out):
            result[current].append((m.group(1), int(m.group(2)), out[n + 1].strip()))
    if proc.returncode != 0 and not failures:
        sys.exit(f"secilc failed on the {name} policy:\n" + "\n".join(out[-15:]))
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("capture")
    ap.add_argument("--lines", type=int, help="read only the first N lines of the capture")
    args = ap.parse_args()

    counts = defaultdict(int)   # (source, target, class, permissions) -> denials
    with open(args.capture, errors="replace") as f:
        for n, line in enumerate(f):
            if args.lines and n >= args.lines:
                break
            if m := DENIAL_RE.search(line):
                counts[(m.group(2), m.group(3), m.group(4), tuple(m.group(1).split()))] += 1
    checks = sorted({(s, t, c, p) for (s, t, c, ps) in counts for p in ps})
    index = {check: i for i, check in enumerate(checks)}

    stock_vers, stock_files = policy_files(DUMP)
    our_vers, our_files = policy_files(OUT)
    with tempfile.TemporaryDirectory() as work:
        stock = allowed(stock_files, [(STOCK_NAME.get(s, s), STOCK_NAME.get(t, t), c, p)
                                      for s, t, c, p in checks], work, "stock")
        ours = allowed(our_files, checks, work, "ours")

    sections = defaultdict(list)   # section -> [(denials, text, stock's rules)]
    for (s, t, c, ps), count in counts.items():
        split = defaultdict(lambda: ([], set()))
        for p in ps:
            i = index[(s, t, c, p)]
            if stock[i] is None:
                key = "n/a"
            elif ours[i]:
                key = "constraint"
            elif stock[i]:
                key = "port"
            else:
                key = "both"
            split[key][0].append(p)
            if key == "port":
                split[key][1].update((os.path.relpath(f, DUMP), l, r) for f, l, r in stock[i])
        for key, (perms, rules) in split.items():
            sections[key].append((count, f"{s} {t}:{c} {{ {' '.join(perms)} }}", sorted(rules)))

    lines = f" (first {args.lines} lines)" if args.lines else ""
    print(f"{args.capture}{lines}: {sum(counts.values())} denials, {len(counts)} unique, "
          f"{len(checks)} permissions")
    print(f"stock policy: vendor platform version {stock_vers}, {len(stock_files)} CIL files; "
          f"ours: {our_vers}, {len(our_files)} CIL files")
    for key, title in SECTIONS:
        rows = sorted(sections[key], key=lambda r: (r[1].split()[0], -r[0], r[1]))
        print(f"\n=== {title}: {len(rows)} ===")
        for count, text, rules in rows:
            print(f"{count:6} {text}")
            for f, l, r in rules[:4]:
                print(f"         {f}:{l} {r}")
            if len(rules) > 4:
                print(f"         ... {len(rules) - 4} more")


if __name__ == "__main__":
    main()
