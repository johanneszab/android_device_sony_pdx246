#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
#
# One-shot setup for a pdx246 (Sony Xperia 10 VI) build.
#
# Takes a freshly `repo sync`ed LineageOS 23.2 tree plus a stock firmware dump
# and leaves you ready to build. Safe to re-run: every step is idempotent.
#
# See README.md for the local manifest that brings in this device tree, the three
# kernel repos and hardware/sony.
#
#   ./device/sony/pdx246/setup.sh /path/to/stock/dump
#
set -euo pipefail

DEVICE=pdx246
VENDOR=sony
DEVICE_PATH="device/${VENDOR}/${DEVICE}"

RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; RST=$'\e[0m'
info()  { printf '%s==>%s %s\n'   "$GRN" "$RST" "$*"; }
warn()  { printf '%s[!]%s %s\n'   "$YLW" "$RST" "$*"; }
die()   { printf '%s[x]%s %s\n'   "$RED" "$RST" "$*" >&2; exit 1; }

# ---------------------------------------------------------------- preflight --
[ -d build/make ] && [ -d .repo ] \
    || die "run this from the ROOT of the LineageOS tree (where .repo lives)"
[ -d "$DEVICE_PATH" ] \
    || die "$DEVICE_PATH missing -- add it to your local manifest and repo sync"

# The kernel, its modules and the device trees are built from source, and
# BoardConfig.mk includes hardware/sony's sepolicy, so these four have to be in
# the tree before anything else works. They come from the local manifest in
# README.md, not from lineage.dependencies (roomservice can only fetch repos
# owned by the LineageOS organisation).
for p in kernel/sony/sm6450/Makefile \
         kernel/sony/sm6450-modules/qcom/opensource \
         kernel/sony/sm6450-devicetrees/qcom/parrot.dtsi \
         hardware/sony/sepolicy/qti/SEPolicy.mk; do
    [ -e "$p" ] || die "missing: $p

The local manifest in $DEVICE_PATH/README.md brings in the device tree, the
three kernel repos (kernel/sony/sm6450, kernel/sony/sm6450-modules and
kernel/sony/sm6450-devicetrees) and hardware/sony. Copy it to
.repo/local_manifests/pdx246.xml and repo sync."
done

# The kernel reaches the device trees through a relative symlink, so they have
# to sit next to it under exactly that name.
[ -e kernel/sony/sm6450/arch/arm64/boot/dts/vendor/qcom/parrot.dtsi ] \
    || die "kernel/sony/sm6450/arch/arm64/boot/dts/vendor does not resolve.
It is a symlink to ../../../../../sm6450-devicetrees; check that
kernel/sony/sm6450-devicetrees is checked out under that exact name." 

# The kernel config fragments BoardConfig.mk names, in the kernel repo.
for c in gki_defconfig vendor/parrot_GKI.config vendor/sony/columbia.config; do
    [ -f "kernel/sony/sm6450/arch/arm64/configs/$c" ] \
        || die "kernel/sony/sm6450 is missing arch/arm64/configs/$c -- wrong branch? (expected 'pdx246')"
done

DUMP="${1:-}"
[ -n "$DUMP" ] || die "usage: $0 /path/to/stock/dump

The dump is an extracted stock firmware for this device (e.g. produced by
dumpyara). It must contain vendor/, system/, product/ and odm/ at its top
level. Blobs are NOT redistributable, so it cannot be shipped with this tree."
[ -d "$DUMP/vendor" ] || die "'$DUMP' does not look like a dump (no vendor/ inside)"

# dumpyara sometimes rewrites a relative symlink (e.g. /vendor/odm -> /odm) into
# an absolute path *inside the dump*, producing a link that points at itself.
# extract-utils then dies with a bare "OSError: Too many levels of symbolic
# links" stack trace, so catch it here and say what to do.
info "Checking the dump for self-referential symlinks"
# NOTE: the `|| true` matters. Under `set -e`, the while loop exits non-zero
# when its final test fails, which would abort the whole script here.
loops=$(find "$DUMP" -maxdepth 3 -type l 2>/dev/null | while read -r l; do
            if [ "$(readlink "$l")" = "$l" ]; then echo "$l"; fi
        done || true)
if [ -n "$loops" ]; then
    printf '%s\n' "$loops" | sed 's/^/    /'
    die "the dump contains symlinks that point at themselves (see above).

They are broken and carry no data, so deleting them is safe:

    find '$DUMP' -type l | while read -r l; do
        [ \"\$(readlink \"\$l\")\" = \"\$l\" ] && rm -v \"\$l\"
    done

then re-run this script."
fi

# ------------------------------------------------------------- 1. the blobs --
# extract-files.py regenerates vendor/sony/pdx246 ENTIRELY from
# proprietary-files.txt, including Android.bp and pdx246-vendor.mk, and applies
# every blob_fixup. Nothing in vendor/ should ever be hand-edited: it is
# generated, unversioned, and this step overwrites it.
info "Extracting proprietary blobs from $DUMP"
info "(this rewrites vendor/${VENDOR}/${DEVICE} from scratch -- expect a few minutes)"
# extract-files.py's shebang sets a RELATIVE PYTHONPATH
# (../../../tools/extract-utils), which only resolves when it is run from the
# device directory. Give it an absolute one so this works from the tree root.
PYTHONPATH="$PWD/tools/extract-utils${PYTHONPATH:+:$PYTHONPATH}" \
    python3 "$DEVICE_PATH/extract-files.py" "$DUMP"

# ------------------------------------------------------------ 2. sanity check --
info "Verifying the results"
fail=0
check() { # path, description
    if [ -e "$1" ]; then printf '    ok       %s\n' "$2"
    else printf '    %sMISSING%s  %s\n' "$RED" "$RST" "$2"; fail=1; fi
}
V="vendor/${VENDOR}/${DEVICE}"
check "$V/Android.bp"                                                     "generated Android.bp"
check "$V/${DEVICE}-vendor.mk"                                            "generated ${DEVICE}-vendor.mk"
check "$V/proprietary/vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl-qti.so" "gatekeeper impl (boot-critical)"
check "$V/proprietary/vendor/lib64/libcld80211.so"                        "libcld80211 (wifi HAL)"
check "$V/proprietary/vendor/lib64/hw/android.hardware.gnss@2.1-impl-qti.so" "gnss impl"
check "$V/proprietary/system_ext/etc/permissions/wfd-system-ext-privapp-permissions-qti.xml" "wfd privapp allowlist"

[ "$fail" -eq 0 ] || die "setup incomplete -- see the MISSING lines above"

# ------------------------------------------------------------------- done --
cat <<EOF

$(printf '%s==>%s') Setup complete. To build:

    source build/envsetup.sh
    lunch lineage_${DEVICE}-bp4a-userdebug
    mka bacon && m superimage

Flashing: see $DEVICE_PATH/README.md and the flash.sh next to the built images.
EOF
