#!/usr/bin/env python3
"""Port stock's SELinux rules for Sony domains (2026-09-12, extended 2026-09-13).

Reads stock's /odm/etc/selinux/odm_sepolicy.cil and converts to .te syntax:
  - every allow, dontaudit and typetransition whose source is one of the
    domains below, and
  - those from other domains whose target is one of these domains, their exec
    types, or one of the new service, hwservice and property types.
The domains are the ones this tree declares (steps 2 and 3a, and the Wi-Fi IDD
HAL) and, since step 3c, the Sony domains hardware/sony/sepolicy declares with
fewer rules than stock. Versioned names (_32_0) become plain names, and stock
names that differ in this policy are mapped. Stock-only attributes are expanded
to their members. Rules from system-side domains (coredomain: apps,
system_server) are skipped: this build has none of Sony's system components,
and such rules in vendor policy run into Treble neverallows. The exceptions
are the service managers, dumpstate and netutils_wrapper, whose rules are the
usual macro expansions in vendor policy; init's rules are ported unless
init_daemon_domain() already provides them. Rules naming a type this policy
lacks are skipped as well. Everything skipped is listed.

Run from the tree root:
  python3 device/sony/pdx246/tools/selinux-port-stock-rules.py [--write]
Without --write it only reports. With --write it replaces the block between
the markers in each domain's .te file (creating the file for a domain declared
elsewhere) and writes stock_clients.te.
"""
import argparse
import os
import re
from collections import defaultdict

# The stock firmware dump (dumpyara); set PDX246_STOCK_DUMP to use another one.
DUMP = os.environ.get("PDX246_STOCK_DUMP", "/run/media/jmeyer/android/dumpyara/working/FILE_21036843")
OUT = "out/target/product/pdx246"
POLICY = "device/sony/pdx246/sepolicy/vendor"

# Domains this tree declares, each in its own .te file.
DOMAINS = ["charge_service", "chargemon", "somc_check_ffu", "somc_check_update",
           "hal_somc_charger_daemon", "hal_somc_thermal_daemon", "hal_superstamina",
           "hal_somc_wifidriver", "pip_firewall", "pmic_key_reset", "spcdeld",
           # stock's hal_somc_wifi_idd_default, a domain since the bring-up; step 3c
           "somc_wifi_idd_hal_service"]
# Sony domains hardware/sony/sepolicy declares (type, labels, part of stock's
# rules); stock's rules for them go into files of their own. Step 3c.
DECLARED_ELSEWHERE = ["idd", "tad", "keyprovd", "vendor_hal_idd_default",
                      "vendor_hal_secd_default", "ta_qmi_service", "mlog_qmi_service"]
ALL_DOMAINS = DOMAINS + DECLARED_ELSEWHERE
NEW_TYPES = [d + "_exec" for d in ALL_DOMAINS] + [
    "hal_somc_charger_service", "hal_somc_thermal_service", "hal_somc_superstamina_service",
    "hal_somc_wifi_idd_service", "hal_wired_se_hwservice", "hal_somc_thermal_hwservice",
    "hal_somc_superstamina_hwservice", "hal_somc_wifidriver_hwservice",
    "vendor_360ra_prop", "vendor_strongbox_prop", "vendor_360ra_restricted_prop",
    "vendor_somc_qcril_prop", "odm_partition_info_prop", "vendor_hal_somc_charger_prop",
    "vendor_somc_camera_prop", "vendor_idd_vendor_product_name_prop",
    "vendor_idd_startupprober_start_prop", "vendor_suntory_prop", "vendor_somc_thermal_prop",
    "vendor_somc_ffu_prop", "vendor_somc_productname_prop", "vendor_somc_variantname_prop",
    "vendor_cali_prop", "vendor_default_status_prop"]
# Stock names that this policy spells differently: hardware/sony/sepolicy's
# vendor_hal_* HALs (their service types keep stock's names), and this tree's
# name for the Wi-Fi IDD HAL.
RENAME = {"hal_idd_hwservice": "vendor_hal_idd_hwservice",
          "hal_somc_wifi_idd_default": "somc_wifi_idd_hal_service",
          "hal_somc_wifi_idd_default_exec": "somc_wifi_idd_hal_service_exec"}
for _hal in ("idd", "miscta", "secd", "spc"):
    for _suffix in ("", "_client", "_server", "_default", "_default_exec"):
        RENAME[f"hal_{_hal}{_suffix}"] = f"vendor_hal_{_hal}{_suffix}"
# System-side domains whose rules for vendor domains are the usual macro
# expansions in vendor policy (binder_use, hwbinder_use, add_service,
# dumpstate's HAL dumps, the callers of netutils_wrapper), so they are ported.
PORT_CORE = {"hwservicemanager", "servicemanager", "vndservicemanager", "dumpstate", "netutils_wrapper"}
# Apps and the framework. Stock's HALs call into them and back because Sony's
# framework and apps use these HALs; this build has neither, and vendor-to-
# system binder rules are what Treble neverallows forbid. Skipped as source
# and as target.
SYSTEM_TARGETS = {"system_server", "platform_app", "system_app", "priv_app",
                  "untrusted_app", "untrusted_app_all", "appdomain"}
# init's rules that init_daemon_domain() already provides.
INIT_COVERED = re.compile(r"^(allow init \S+_exec:file \{ read getattr map execute open \};|"
                          r"allow init \S+:process \{ (transition|siginh rlimitinh) \};|"
                          r"dontaudit init \S+:process \{ noatsecure \};|"
                          r"type_transition init \S+_exec:process \S+;)$")
# Types this port declares itself (stock_types.te in the device policy), counted
# as known.
EXTRA_KNOWN = {"charge_log_file", "sysfs_scsi_dev_model", "sysfs_scsi_dev_rev", "sysfs_dp_is_stopped"}
# HAL attributes this port declares itself (sepolicy/vendor/attributes). Stock's
# rules for them stay expanded to the member domains, as they were when the
# attributes did not exist yet, so a rebuild does not move rules between files.
PORT_ATTRS = {"hal_somc_charger", "hal_somc_charger_client", "hal_somc_charger_server",
              "hal_somc_wifi_idd", "hal_somc_wifi_idd_client", "hal_somc_wifi_idd_server"}
MARK_BEGIN = "# --- rules ported from stock's odm_sepolicy.cil (tools/selinux-port-stock-rules.py) ---"
# Earlier marker text, replaced on the next --write.
OLD_MARKS = ["# --- rules ported from stock's odm_sepolicy.cil (build-logs/selinux-port-stock-rules.py) ---"]
MARK_END = "# --- end of ported rules ---"

RULE_RE = re.compile(r"^\((allow|dontaudit) (\S+) (\S+) \((\S+) \(([^()]*)\)\)\)$")
TT_RE = re.compile(r'^\(typetransition (\S+) (\S+) (\S+) (?:"([^"]*)" )?(\S+)\)$')


def plain(t):
    t = re.sub(r"_32_0$", "", t)
    return RENAME.get(t, t)


def read(path):
    with open(path, errors="replace") as f:
        return f.read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    stock = read(DUMP + "/odm/etc/selinux/odm_sepolicy.cil")
    ours = ""
    for f in ("/system/etc/selinux/plat_sepolicy.cil", "/system_ext/etc/selinux/system_ext_sepolicy.cil",
              "/product/etc/selinux/product_sepolicy.cil", "/vendor/etc/selinux/vendor_sepolicy.cil",
              "/odm/etc/selinux/odm_sepolicy.cil"):
        if os.path.exists(OUT + f):
            ours += read(OUT + f)
    known = set(re.findall(r"^\((?:type|typeattribute) (\S+)\)", ours, re.M)) | {"self"} | EXTRA_KNOWN
    core = set()
    for members in re.findall(r"^\(typeattributeset coredomain \(([^)]*)\)\)", ours, re.M):
        core |= set(members.split())
    stock_attrs = {a: [plain(m) for m in members.split()]
                   for a, members in re.findall(r"^\(typeattributeset (\S+) \(([^)]*)\)\)", stock, re.M)}

    def expand(t):
        """Plain type, or the existing members of a stock-only attribute."""
        t = plain(t)
        if t in PORT_ATTRS:
            return [m for m in stock_attrs.get(t, []) if m in known]
        if t in known or t not in stock_attrs:
            return [t]
        return [m for m in stock_attrs[t] if m in known]

    targets = set(ALL_DOMAINS) | set(NEW_TYPES)
    own = defaultdict(list)       # domain -> rules with that domain as source
    clients = defaultdict(list)   # other source -> rules into the domains and new types
    skipped = []
    for line in stock.splitlines():
        line = line.strip()
        m = RULE_RE.match(line)
        tt = None if m else TT_RE.match(line)
        if not m and not tt:
            continue
        src_raw, tgt_raw = (m.group(2), m.group(3)) if m else (tt.group(1), tt.group(2))
        src_p, tgt_p = plain(src_raw), plain(tgt_raw)
        if tt:
            new_p = plain(tt.group(5))
            if src_p not in ALL_DOMAINS and new_p not in targets:
                continue
        elif src_p not in ALL_DOMAINS and tgt_p not in targets:
            continue
        for src in expand(src_raw):
            for tgt in expand(tgt_raw):
                if m:
                    text = f"{m.group(1)} {src} {tgt}:{m.group(4)} {{ {m.group(5)} }};"
                    missing = [x for x in (src, tgt) if x not in known]
                else:
                    name = f' "{tt.group(4)}"' if tt.group(4) else ""
                    text = f"type_transition {src} {tgt}:{tt.group(3)} {plain(tt.group(5))}{name};"
                    missing = [x for x in (src, tgt, plain(tt.group(5))) if x not in known]
                if missing:
                    skipped.append((f"missing {' '.join(missing)}", text))
                elif src == "init" and INIT_COVERED.match(text):
                    skipped.append(("init, covered by init_daemon_domain", text))
                elif (src in core and src not in PORT_CORE and src != "init") or src in SYSTEM_TARGETS:
                    skipped.append(("system side", text))
                elif tgt in SYSTEM_TARGETS:
                    skipped.append(("system-side target", text))
                elif src in ALL_DOMAINS:
                    own[src].append(text)
                else:
                    clients[src].append(text)
        if not expand(src_raw) or not expand(tgt_raw):
            skipped.append(("no member in this policy", line[:160]))

    total = sum(len(v) for v in own.values()) + sum(len(v) for v in clients.values())
    print(f"ported rules: {total} ({sum(len(v) for v in own.values())} from the domains, "
          f"{sum(len(v) for v in clients.values())} from {len(clients)} other domains)")
    for d in ALL_DOMAINS:
        print(f"  {d}: {len(own[d])}")
    for s in sorted(clients):
        print(f"  from {s}: {len(clients[s])}")
    print(f"skipped: {len(skipped)}")
    for why, text in skipped:
        print(f"  [{why}] {text}")

    if not args.write:
        return
    for d in ALL_DOMAINS:
        path = f"{POLICY}/{d}.te"
        rules = sorted(set(own[d]))
        if os.path.exists(path):
            body = read(path)
            for mark in [MARK_BEGIN] + OLD_MARKS:
                if mark in body:
                    body = body[:body.index(mark)].rstrip("\n") + "\n"
                    break
        elif rules:
            body = (f"# Stock's rules for {d}. hardware/sony/sepolicy declares the domain,\n"
                    "# with its labels and part of stock's rules.\n")
        else:
            continue
        if rules:
            body += "\n" + MARK_BEGIN + "\n" + "\n".join(rules) + "\n" + MARK_END + "\n"
        with open(path, "w") as f:
            f.write(body)
    lines = ["# Rules from other vendor domains into the Sony types, ported from stock's",
             "# odm_sepolicy.cil by tools/selinux-port-stock-rules.py. Regenerate",
             "# rather than edit. Rules from system-side domains (Sony apps,",
             "# system_server) are not ported."]
    for s in sorted(clients):
        lines.append("")
        lines.append(f"# {s}")
        lines.extend(sorted(set(clients[s])))
    with open(f"{POLICY}/stock_clients.te", "w") as f:
        f.write("\n".join(lines) + "\n")
    print("written")


if __name__ == "__main__":
    main()
