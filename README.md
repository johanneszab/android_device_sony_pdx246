# LineageOS 23.x for the Sony Xperia 10 VI (pdx246)

Bring-up in progress. Boots to the LineageOS UI with Wi-Fi, cellular, audio and
GPS working; see [PORTING-NOTES.md](PORTING-NOTES.md) for the full engineering
history, and its ">>> PICK UP HERE <<<" section for what does and does not work
today.

## Reproducing a build

### What you need

1. **A LineageOS 23.x tree**, synced.
2. **This device tree** at `device/sony/pdx246` (local manifest).
3. **A stock firmware dump** for the device, extracted — e.g. with
   [dumpyara](https://github.com/AndroidDumps/dumpyara). It must have
   `vendor/`, `system/`, `product/` and `odm/` at its top level.
   Blobs are not redistributable, so this cannot be shipped here; the
   dump used for the current state was Sony build `70.2.A.4.22`.
4. **The kernel**, at `kernel/sony/pdx246` and `kernel/sony/pdx246-modules`.
   Currently these are Sony's GPL release (`70.2.A.4.22.tar.bz2`) with
   `a16-columbia/kernel_platform/msm-kernel` and `a16-columbia/vendor`
   symlinked into place. **The kernel is not built** — `TARGET_PREBUILT_KERNEL`
   wins and `prebuilts/kernel` ships verbatim — so these are only needed for
   headers. See the "Sony kernel source release" section of the notes.

### Then

```bash
./device/sony/pdx246/setup.sh /path/to/stock/dump
```

That does everything reproducible in one pass:

- re-applies the out-of-tree patches in `patches/aosp/` to AOSP/LineageOS
  projects (a `repo sync` reverts these, so re-run setup after every sync)
- runs `extract-files.py`, which regenerates **all** of `vendor/sony/pdx246`
  from `proprietary-files.txt` — including `Android.bp`, `pdx246-vendor.mk`
  and every `blob_fixup`
- verifies that the blobs which broke the boot before are present

Then build:

```bash
export WITH_ADB_INSECURE=true
source build/envsetup.sh
lunch lineage_pdx246-trunk_staging-userdebug
rm -f out/target/product/pdx246/{boot,vendor_boot}.img
mka bacon && m superimage
```

Three things about that invocation are not optional:

| | why |
|---|---|
| `WITH_ADB_INSECURE=true` | LineageOS sets `ro.adb.secure=1` and `ro.debuggable=0` on any non-`eng` build. Without this, adb needs an on-screen RSA prompt you cannot tap when the UI is not coming up, and `adb root` is gone. Drop it for a release build. |
| `-userdebug`, never `-eng` | `eng` sets `OVERRIDE_DISABLE_DEXOPT_ALL`, which disables dexpreopt. First boot then compiles the boot classpath on device for both architectures — measured at over two hours. |
| `rm -f ...boot.img` | `--dtb` is passed via `BOARD_MKBOOTIMG_ARGS` and is **not** a tracked dependency, so a changed `prebuilts/dtb.img` silently ships stale. |

Keep `trunk_staging` as the release. `lineage_pdx246-bp2a-userdebug` also
resolves but silently changes the release config as well as the variant.

Flashing: see the "Flashing" section of the notes. **Always use explicit `_a`
suffixes and finish with `fastboot --set-active=a`** — the bootloader
under-reports `has-slot`, and a failed boot burns the slot retry counter until
it fails over to the empty slot b and red-states with "device is corrupt".

## What is deliberately not in this repo

**`vendor/sony/pdx246` is generated and unversioned.** Never hand-edit it —
`setup.sh` overwrites it wholesale. Anything that must persist belongs in
`proprietary-files.txt` (which files to pull) or in `extract-files.py`
(`blob_fixups`, for modifications to a blob).

**Out-of-tree source changes** live in `patches/aosp/`. They are re-applied by
`setup.sh` rather than upstreamed, since they are too device-specific to land.

## Wiping data

Wipe `/data` after **any** change to what is on `/system` that does not change
the fingerprint — a build-variant switch above all. `ro.build.fingerprint` is
spoofed to Sony stock and is therefore identical across our builds, so Android
never invalidates `/data/dalvik-cache` or the RRO idmaps by itself, and you get
a new system running against the old build's artifacts (Zygote dies, ~10 s of
boot animation, reboot loop).

Conversely do **not** wipe merely because a boot is slow: an interrupted dexopt
resumes from `/data/dalvik-cache`, and wiping restarts it. The question is "did
the system image change underneath the existing /data?", not "is this slow?".

## Current state / where to resume

`PORTING-NOTES.md` is the working log. Start at the section
**">>> PICK UP HERE (next session) <<<"** at the top -- it says exactly what is
done, what is unproven, and what to do next.

Short version: the device boots to the LineageOS UI with no crash-looping
services. Wi-Fi, cellular, audio and GPS are verified working; a full feature
test pass has not been done yet. SELinux is still permissive, and the build
still carries debug-only settings (see "MUST REVERT before any real use").

## Flashing

    ./device/sony/pdx246/flash.sh

Do not flash by hand unless you have read the "Flashing" section of
PORTING-NOTES.md -- `super.img` needs `fastboot -S 256M` on this bootloader, and
a dropped USB partway through leaves the device unbootable until super is
rewritten.
