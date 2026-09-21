#!/usr/bin/env python3
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
"""SELinux label pre-check for pdx246 (2026-09-12).

Compares the SELinux file label of every executable we ship in /vendor/bin and
/odm/bin (taken from the build output) with the label stock gives it, and shows
which of the missing ones hardware/sony/sepolicy would provide. With the phone
on adb it also lists the processes that still run in init's domain, i.e. the
services and helpers that never got a domain of their own.

Run from the tree root:
  python3 device/sony/pdx246/tools/selinux-label-check.py [--serial HQ648T0A9D]
"""
import argparse
import glob
import os
import re
import subprocess

# The stock firmware dump (dumpyara); set PDX246_STOCK_DUMP to use another one.
DUMP = os.environ.get("PDX246_STOCK_DUMP", "")
if not DUMP:
    raise SystemExit("set PDX246_STOCK_DUMP to an extracted stock firmware dump")
OUT = "out/target/product/pdx246"
# Labels that give an executable no domain of its own.
GENERIC = {"vendor_file", "vendor_toolbox_exec", "odm_file", "-"}


def load(files):
    specs = []
    for f in files:
        if not os.path.exists(f):
            continue
        for line in open(f, errors="replace"):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            t = s.split()
            try:
                specs.append((re.compile("^(" + t[0] + ")$"), t[-1]))
            except re.error:
                pass
    return specs


def lookup(specs, path):
    # libselinux takes the last matching entry of the (sorted) file.
    ctx = "-"
    for rx, c in specs:
        if rx.match(path):
            ctx = c
    return ctx.replace("u:object_r:", "").replace(":s0", "")


def read_entries(files):
    """name -> (type, exact) for *_contexts files: 'name context [exact|prefix] [type]'."""
    entries = {}
    for f in files:
        if not os.path.exists(f):
            continue
        for line in open(f, errors="replace"):
            t = line.split()
            if len(t) < 2 or t[0].startswith("#"):
                continue
            ctype = t[1].replace("u:object_r:", "").replace(":s0", "")
            entries[t[0]] = (ctype, len(t) > 2 and t[2] == "exact")
    return entries


def lookup_service(ours, name):
    if name in ours:
        return ours[name][0]
    if "*" in ours:
        return ours["*"][0]
    return "-"


def lookup_property(ours, name):
    # Longest matching prefix wins; exact entries only match the whole name.
    best, best_len = "-", -1
    for key, (ctype, exact) in ours.items():
        if exact:
            if key == name and len(key) > best_len:
                best, best_len = ctype, len(key)
        elif name.startswith(key) and len(key) > best_len:
            best, best_len = ctype, len(key)
    return best


def contexts_check():
    sel = {"stock-vendor": DUMP + "/vendor/etc/selinux/", "stock-odm": DUMP + "/odm/etc/selinux/"}
    ours_dirs = [OUT + "/system/etc/selinux/plat_", OUT + "/system_ext/etc/selinux/system_ext_",
                 OUT + "/product/etc/selinux/product_", OUT + "/vendor/etc/selinux/vendor_",
                 OUT + "/odm/etc/selinux/odm_"]
    kinds = [("service_contexts", lookup_service, {"default_android_service"}),
             ("hwservice_contexts", lookup_service, {"default_android_hwservice"}),
             ("vndservice_contexts", lookup_service, {"default_android_vndservice"}),
             ("property_contexts", lookup_property, {"default_prop", "vendor_default_prop"})]
    for kind, lookup, generic in kinds:
        stock_files = [sel["stock-vendor"] + "vendor_" + kind, sel["stock-odm"] + "odm_" + kind]
        if kind == "vndservice_contexts":
            stock_files = [sel["stock-vendor"] + kind]
            ours_files = [OUT + "/vendor/etc/selinux/" + kind]
        else:
            ours_files = [d + kind for d in ours_dirs]
        stock = read_entries(stock_files)
        ours = read_entries(ours_files)
        gaps, renamed = [], []
        for name, (stype, _) in sorted(stock.items()):
            o = lookup(ours, name)
            if o == stype:
                continue
            if o == "-" or o in generic:
                gaps.append((name, stype, o))
            else:
                renamed.append((name, stype, o))
        print(f"{kind}: {len(stock)} stock entries, {len(gaps)} missing or generic in ours, "
              f"{len(renamed)} with a different type")
        for name, stype, o in gaps:
            print(f"  missing  {name:64} stock={stype} ours={o}")
        for name, stype, o in renamed[:15]:
            print(f"  renamed  {name:64} stock={stype} ours={o}")
        if len(renamed) > 15:
            print(f"  renamed  ... {len(renamed) - 15} more")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--serial", default="HQ648T0A9D")
    args = ap.parse_args()

    stock = load([DUMP + "/vendor/etc/selinux/vendor_file_contexts"]
                 + glob.glob(DUMP + "/odm/etc/selinux/*file_contexts"))
    sony = load(glob.glob("hardware/sony/sepolicy/qti/vendor/**/file_contexts", recursive=True))
    ours = load([OUT + "/system/etc/selinux/plat_file_contexts",
                 OUT + "/vendor/etc/selinux/vendor_file_contexts"]
                + glob.glob(OUT + "/odm/etc/selinux/*file_contexts"))

    exes = []
    for part in ("vendor", "odm"):
        for dirpath, _, files in os.walk(f"{OUT}/{part}/bin"):
            for f in files:
                full = os.path.join(dirpath, f)
                if not os.path.islink(full):
                    exes.append("/" + os.path.relpath(full, OUT))

    missing = []
    for p in sorted(exes):
        o, s = lookup(ours, p), lookup(stock, p)
        if o in GENERIC and s.endswith("_exec"):
            missing.append((p, s, lookup(sony, p)))
    print(f"executables in /vendor/bin and /odm/bin: {len(exes)}")
    print(f"plain label in our build, domain on stock: {len(missing)} "
          f"(hardware/sony/sepolicy labels {sum(1 for m in missing if m[2] != '-')} of them)")
    for p, s, y in missing:
        print(f"  {p:62} stock={s:34} sony={y}")

    contexts_check()

    try:
        ps = subprocess.run(["adb", "-s", args.serial, "shell", "ps -A -o PID,LABEL,ARGS"],
                            capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.TimeoutExpired):
        ps = ""
    if not ps:
        print("(no phone on adb: process check skipped)")
        return
    rows = [line.split(None, 2) for line in ps.splitlines()[1:]]
    in_init = sorted(r[2].split()[0] for r in rows
                     if len(r) == 3 and r[1] == "u:r:init:s0" and r[0] != "1")
    print(f"processes in init's domain besides init: {len(in_init)}")
    for name in in_init:
        print(f"  {name}")


if __name__ == "__main__":
    main()
