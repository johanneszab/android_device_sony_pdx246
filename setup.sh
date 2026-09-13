#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# One-shot setup for a pdx246 (Sony Xperia 10 VI) build.
#
# Takes a freshly `repo sync`ed LineageOS 23.x tree plus a stock firmware dump
# and leaves you ready to build. Safe to re-run: every step is idempotent.
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

# --------------------------------------------------- 1. out-of-tree patches --
# Changes to AOSP/LineageOS projects that a `repo sync` will revert. They are
# device-specific enough that upstreaming them is not realistic, so they live
# here and get re-applied.
info "Applying out-of-tree patches"
declare -A PATCH_PROJECT=(
  [frameworks_native]="frameworks/native"
  [system_sepolicy]="system/sepolicy"
  [device_qcom_sepolicy]="device/qcom/sepolicy"
  [device_qcom_sepolicy_vndr_sm8450]="device/qcom/sepolicy_vndr/sm8450"
  [external_skia]="external/skia"
  [external_google-highway]="external/google-highway"
  [external_mdnsresponder]="external/mdnsresponder"
  [external_XMP-Toolkit-SDK]="external/XMP-Toolkit-SDK"
  [hardware_interfaces]="hardware/interfaces"
  [hardware_qcom-caf_bootctrl]="hardware/qcom-caf/bootctrl"
  [bionic]="bionic"
)
for name in "${!PATCH_PROJECT[@]}"; do
    patch_file="$PWD/$DEVICE_PATH/patches/aosp/${name}.patch"
    project="${PATCH_PROJECT[$name]}"
    [ -f "$patch_file" ] || { warn "no patch file for $name, skipping"; continue; }
    if [ ! -d "$project" ]; then
        warn "project $project not in this tree, skipping ${name}.patch"
        continue
    fi
    if git -C "$project" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
        printf '    already applied  %s\n' "$project"
    elif git -C "$project" apply --check "$patch_file" >/dev/null 2>&1; then
        git -C "$project" apply "$patch_file"
        printf '    applied          %s\n' "$project"
    else
        die "${name}.patch does not apply to $project.
Upstream has probably moved. Rebase the patch by hand, then re-run."
    fi
done

# ----------------------------------------------- 1b. pdx257 reference trees --
# device/sony/pdx257 and vendor/sony/pdx257, where present, are only a reference:
# nothing in the pdx246 build uses them. soong parses every Android.bp in the
# tree whatever the lunch target, and pdx257's vendor tree fails analysis here
# (its vendor.libdpmframework links the system_ext copy of
# com.qualcomm.qti.dpm.api@1.0, which has no vendor variant). A .find-ignore file
# makes soong's finder skip its directory, so both trees are hidden instead of
# patched; they go together because device/sony/pdx257/qcril-database refers to
# the vendor tree. Delete the two files to build pdx257.
info "Hiding the pdx257 reference trees from the build"
for ref in device/sony/pdx257 vendor/sony/pdx257; do
    [ -d "$ref" ] || continue
    if [ -e "$ref/.find-ignore" ]; then
        printf '    already hidden   %s\n' "$ref"
    else
        touch "$ref/.find-ignore"
        printf '    hidden           %s\n' "$ref"
    fi
done

# ------------------------------------------------------------- 2. the blobs --
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

# ------------------------------------------------------------ 3. sanity check --
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
    lunch lineage_${DEVICE}-trunk_staging-userdebug
    rm -f out/target/product/${DEVICE}/{boot,vendor_boot}.img
    mka bacon && m superimage

That is the release configuration: LineageOS sets ro.adb.secure=1 and
ro.debuggable=0, so USB debugging needs the prompt on the phone and 'adb root'
is gone. For bring-up or debugging, 'export WITH_ADB_INSECURE=true' before
building: adb then works without the prompt, also when the UI does not come
up, and the build stays debuggable.

Do NOT build 'eng': it disables dexpreopt entirely and the first boot then
spends 2+ hours compiling the boot classpath on device.

The 'rm -f ...boot.img' is not optional -- --dtb is passed through
BOARD_MKBOOTIMG_ARGS and is not a tracked dependency, so a changed
prebuilts/dtb.img otherwise ships stale.

Flashing instructions: see the "Flashing" section of $DEVICE_PATH/PORTING-NOTES.md
EOF
