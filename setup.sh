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
  [device_qcom_sepolicy_vndr_sm8450]="device/qcom/sepolicy_vndr/sm8450"
  [external_skia]="external/skia"
  [external_google-highway]="external/google-highway"
  [external_mdnsresponder]="external/mdnsresponder"
  [external_XMP-Toolkit-SDK]="external/XMP-Toolkit-SDK"
  [hardware_interfaces]="hardware/interfaces"
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

# ---------------------------------------- 1b. audio: source-built QTI AIDL HAL --
# The QTI audio HAL is built from hardware/qcom-caf/sm8450-6.6/audio. Four repo
# projects there need patching, plus vendor/lineage and pdx257 -- see
# PORTING-NOTES.md "AUDIO" for why each one is needed.
info "Applying audio HAL patches"
declare -A AUDIO_PATCH_PROJECT=(
  ["hardware_qcom-caf_sm8450-6.6_audio_agm"]="hardware/qcom-caf/sm8450-6.6/audio/agm"
  ["hardware_qcom-caf_sm8450-6.6_audio_graphservices"]="hardware/qcom-caf/sm8450-6.6/audio/graphservices"
  ["hardware_qcom-caf_sm8450-6.6_audio_pal"]="hardware/qcom-caf/sm8450-6.6/audio/pal"
  ["hardware_qcom-caf_sm8450-6.6_audio_primary-hal"]="hardware/qcom-caf/sm8450-6.6/audio/primary-hal"
  [vendor_lineage]="vendor/lineage"
  [device_sony_pdx257]="device/sony/pdx257"
)
for name in "${!AUDIO_PATCH_PROJECT[@]}"; do
    patch_file="$PWD/$DEVICE_PATH/patches/audio/${name}.patch"
    project="${AUDIO_PATCH_PROJECT[$name]}"
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

# hardware/qcom-caf/sm8450-6.6/audio/ is a PLAIN DIRECTORY -- agm, graphservices,
# pal and primary-hal below it are separate repo projects, but the parent is not
# tracked by anything. So the nested soong_namespace that keeps display and the
# IPA trees out of our namespace cannot be a patch; it is copied in.
NS_BP="hardware/qcom-caf/sm8450-6.6/audio/Android.bp"
if [ -d "$(dirname "$NS_BP")" ]; then
    if ! cmp -s "$DEVICE_PATH/patches/audio/files/sm8450-6.6_audio_Android.bp" "$NS_BP"; then
        cp "$DEVICE_PATH/patches/audio/files/sm8450-6.6_audio_Android.bp" "$NS_BP"
        printf '    installed        %s\n' "$NS_BP"
    else
        printf '    already present  %s\n' "$NS_BP"
    fi
fi

# vendor/lineage/tools/clean_headers.sh is invoked BY PATH from the
# generated_kernel_includes genrule and is NOT one of its tracked inputs, so
# soong will not notice the patch above. Force a regeneration.
KGEN="out/soong/.intermediates/vendor/lineage/build/soong/generated_kernel_includes"
if [ -d "$KGEN" ] && grep -q 'struct epoll_event' \
     "$KGEN/gen/usr/include/linux/eventpoll.h" 2>/dev/null; then
    rm -rf "$KGEN"
    printf '    purged stale     %s\n' "$KGEN"
fi

# ------------------------------------------------------------- 2. the blobs --
# extract-files.py regenerates vendor/sony/pdx246 ENTIRELY from
# proprietary-files.txt, including Android.bp and pdx246-vendor.mk, and applies
# every blob_fixup (among them the GNSS HIDL patch -- see
# patches/gnss-hidl-nonfatal.md). Nothing in vendor/ should ever be hand-edited:
# it is generated, unversioned, and this step overwrites it.
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

gnss="$V/proprietary/vendor/bin/hw/android.hardware.gnss-aidl-service-qti"
if [ -f "$gnss" ]; then
    word=$(python3 -c "import struct,sys;print('%08x'%struct.unpack_from('<I',open(sys.argv[1],'rb').read(),0x54c4)[0])" "$gnss")
    if [ "$word" = "14000030" ]; then printf '    ok       gnss HIDL patch applied (0x54c4=0x%s)\n' "$word"
    else printf '    %sBAD%s      gnss HIDL patch NOT applied (0x54c4=0x%s, want 14000030)\n' "$RED" "$RST" "$word"; fail=1; fi
fi
[ "$fail" -eq 0 ] || die "setup incomplete -- see the MISSING/BAD lines above"

# ------------------------------------------------------------------- done --
cat <<EOF

$(printf '%s==>%s') Setup complete. To build:

    export WITH_ADB_INSECURE=true          # see below -- needed for adb
    source build/envsetup.sh
    lunch lineage_${DEVICE}-trunk_staging-userdebug
    rm -f out/target/product/${DEVICE}/{boot,vendor_boot}.img
    mka bacon && m superimage

WITH_ADB_INSECURE=true is REQUIRED for bring-up. Without it LineageOS sets
ro.adb.secure=1 and ro.debuggable=0 on any non-eng build, so adb needs an
on-screen RSA prompt you cannot tap if the UI does not come up, and 'adb root'
is gone. Drop it for a release build.

Do NOT build 'eng': it disables dexpreopt entirely and the first boot then
spends 2+ hours compiling the boot classpath on device.

The 'rm -f ...boot.img' is not optional -- --dtb is passed through
BOARD_MKBOOTIMG_ARGS and is not a tracked dependency, so a changed
prebuilts/dtb.img otherwise ships stale.

Flashing instructions: see the "Flashing" section of $DEVICE_PATH/PORTING-NOTES.md
EOF
