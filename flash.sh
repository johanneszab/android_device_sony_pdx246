#!/bin/bash
# Flash pdx246. Handles this host's flaky USB by waiting for the device and
# retrying each step. Safe to re-run: every step is idempotent.
#
#   ./device/sony/pdx246/flash.sh [out/target/product/pdx246]
set -u
IMG="${1:-out/target/product/pdx246}"
[ -d "$IMG" ] || { echo "no image dir: $IMG"; exit 1; }
cd "$IMG" || exit 1

# The Sony bootloader truncates getvar names ("max-downlo not supported"), so
# fastboot cannot negotiate max-download-size and tries to send super.img whole,
# which the bootloader rejects. -S forces resparsing into chunks.
CHUNK=256M

wait_fastboot() {
    local n=0
    until fastboot devices 2>/dev/null | grep -q fastboot; do
        n=$((n+1))
        [ $n -eq 1 ] && echo "  ... waiting for fastboot (reconnect USB if needed)"
        [ $n -gt 300 ] && { echo "  TIMEOUT waiting for device"; return 1; }
        sleep 2
    done
    return 0
}

flash() {   # flash <partition> <image> [extra fastboot args...]
    local part="$1" img="$2"; shift 2
    [ -f "$img" ] || { echo "  SKIP $part (no $img)"; return 0; }
    local try out rc
    for try in 1 2 3 4 5; do
        wait_fastboot || return 1
        echo "  [$try] flash $part <- $img"
        # Capture instead of piping: a pipe would make $? come from tail, not
        # fastboot, and fastboot also exits 0 on some remote failures -- so check
        # BOTH the exit status and the output text.
        out=$(fastboot "$@" -S $CHUNK flash "$part" "$img" 2>&1); rc=$?
        echo "$out" | tail -3 | sed 's/^/      /'
        if [ $rc -eq 0 ] && ! echo "$out" | grep -qiE 'FAILED|error:'; then
            echo "      ok"
            return 0
        fi
        echo "      retrying (reconnect the cable if it dropped off the bus)"
        sleep 5
    done
    echo "  FAILED after 5 tries: $part"
    return 1
}

echo "== super (largest, ~4-6 min; most likely to hit the USB drop) =="
flash super super.img || exit 1

echo "== vbmeta =="
flash vbmeta_a        vbmeta.img        --disable-verity --disable-verification || exit 1
flash vbmeta_system_a vbmeta_system.img --disable-verity --disable-verification || exit 1

echo "== boot chain =="
flash boot_a        boot.img        || exit 1
flash dtbo_a        dtbo.img        || exit 1
flash recovery_a    recovery.img    || exit 1
flash vendor_boot_a vendor_boot.img || exit 1

echo "== set active slot a =="
# The bootloader under-reports has-slot, so always use explicit _a suffixes.
# Slot a is never marked successful while boot fails, so its retry counter burns
# down; after ~7 failures the bootloader fails over to empty slot b and
# red-states with "device is corrupt". --set-active=a fixes that.
wait_fastboot && fastboot --set-active=a 2>&1 | tail -2 | sed 's/^/  /'

echo
echo "Done. 'fastboot reboot' to boot it."
