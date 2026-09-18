# LineageOS 23.2 for the Sony Xperia 10 VI (pdx246)

An unofficial port, built and used daily on the author's device. The kernel is
built from source; the proprietary parts come from a stock firmware dump that
you supply yourself.

[PORTING-NOTES.md](PORTING-NOTES.md) is the engineering log of the port: why
things are the way they are, what was tried, and what is still open. Its
">>> PICK UP HERE <<<" section is the current state. Paths in it refer to the
author's machine.

## State of the port

Working: boot to the UI, display and touch, Wi-Fi (including the 5 GHz
hotspot), Bluetooth, NFC with the secure element, mobile data, calls, VoLTE and
Wi-Fi calling, GPS, audio including the speaker, headset and in-call paths, all
five cameras with photo and video, hardware video decoding, the fingerprint
sensor, sensors, the vibrator, charging with LineageOS charging control,
LiveDisplay, and suspend on battery (98% asleep with the screen off). SELinux
is enforcing.

Not working or absent:

| | |
|---|---|
| FM radio | Never worked. The stock device tree has no node for the tuner chip, so the driver finds no device. |
| Tap to wake | Not possible with this touch firmware: the controller reports gesture id 0, so the driver can never tell a double tap from anything else. |
| Firefox (156 and newer) | Crashes at startup, on this port and on any Android 16 device: it targets SDK 37 and calls a hidden `MessageQueue` method the platform blocks. Not a port problem; other browsers work. |
| Device trees | `prebuilts/dtb.img` and `prebuilts/dtbo.img` are still the stock binaries. Everything else, kernel and all 351 vendor modules, is built from source. |

Two things to know before you install it: the build uses AOSP test keys (so it
is not a "secure" release build), and an occasional crash of the vendor audio
HAL at boot has been seen once in about forty boots. It restarts itself and
audio works.

## What you need

1. **A LineageOS 23.2 tree.** About 220 GB for `.repo` plus the checkout, and
   another ~210 GB for `out/`, so plan for roughly 450 GB free. A full build
   takes about three hours on a 20-core machine.
2. **This device tree and the two kernel repos**, via the local manifest below.
   They are all the port needs on top of the LineageOS default manifest, plus
   `hardware/sony`, which the default manifest does not carry.
3. **A stock firmware dump** for this exact device, extracted (for example with
   [dumpyara](https://github.com/AndroidDumps/dumpyara)), with `vendor/`,
   `system/`, `product/` and `odm/` at its top level. Blobs are not
   redistributable, so they are not part of any of these repos. The current
   state was built from `XQ-ES54_EEA-user 16 70.2.A.4.168`
   (`070002A004016801749288677`). A different firmware version may work but has
   not been tested; PORTING-NOTES.md describes how a wrong dump shows up.

The kernel repos are separate because the kernel is built from source:

| Path | Repo | Branch |
|---|---|---|
| `device/sony/pdx246` | `android_device_sony_pdx246` | `bringup` |
| `kernel/sony/sm6450` | `android_kernel_sony_sm6450` | `pdx246` |
| `kernel/sony/sm6450-modules` | `android_kernel_sony_sm6450-modules` | `lineage-23.2` |

The kernel is a fork of LineageOS's `android_kernel_sony_sm8450` (its
`lineage-23.2` branch is that upstream unchanged; `pdx246` adds this device's
drivers and config). The modules repo holds Sony's vendor module sources plus
LineageOS's WLAN driver. SM6450 is this device's SoC — do not confuse it with
the sm8450 devices (Xperia 1 IV, 5 IV).

## Checkout

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs
mkdir -p .repo/local_manifests
cp /path/to/pdx246.xml .repo/local_manifests/pdx246.xml   # see below
repo sync -c -j8
```

The manifest to copy is [local_manifests/pdx246.xml](local_manifests/pdx246.xml)
in this repo; its content is:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="johanneszab" fetch="https://github.com/johanneszab" />

  <project path="device/sony/pdx246" name="android_device_sony_pdx246"
           remote="johanneszab" revision="bringup" />
  <project path="kernel/sony/sm6450" name="android_kernel_sony_sm6450"
           remote="johanneszab" revision="pdx246" />
  <project path="kernel/sony/sm6450-modules" name="android_kernel_sony_sm6450-modules"
           remote="johanneszab" revision="lineage-23.2" />

  <project path="hardware/sony" name="LineageOS/android_hardware_sony"
           remote="github" />
</manifest>
```

`lineage.dependencies` in this repo only names `hardware/sony`, because
roomservice can only fetch repos owned by the LineageOS organisation. The three
repos above therefore have to come from the local manifest.

The kernel repo carries the full upstream history and is about 3.8 GB. Add
`clone-depth="1"` to that project if you do not need the history; the build
does not.

## Setup and build

```bash
./device/sony/pdx246/setup.sh /path/to/stock/dump
source build/envsetup.sh
lunch lineage_pdx246-trunk_staging-userdebug
rm -f out/target/product/pdx246/{boot,vendor_boot}.img
mka bacon && m superimage
```

`setup.sh` is idempotent and does three things: it re-applies the out-of-tree
patches in `patches/aosp/`, regenerates `vendor/sony/pdx246` from your dump with
`extract-files.py`, and checks that the blobs that used to break the boot are
present. Run it again after every `repo sync`, because a sync reverts the
patches.

The patches touch eleven upstream projects. `repo sync` will complain about
those projects while the patches are applied; reverse them first, or let the
sync overwrite them and re-run `setup.sh` afterwards:

```bash
for p in device/sony/pdx246/patches/aosp/*.patch; do
    n=$(basename "$p" .patch)
    git -C "${n//_//}" apply -R "$p" 2>/dev/null
done
```

Four points about that build invocation:

| | why |
|---|---|
| `lunch lineage_pdx246-...` in full | `breakfast pdx246` and `brunch pdx246` take the release from `vendor/lineage/vars/aosp_target_release` (currently `bp4a`) and silently build a different release configuration. |
| `-userdebug`, never `-eng` | `eng` disables dexpreopt, and the first boot then compiles the boot classpath on the device for over two hours. |
| `rm -f ...vendor_boot.img` | The stock dtb reaches mkbootimg through `BOARD_MKBOOTIMG_ARGS`, which ninja does not track. With boot header v4 the dtb rides in `vendor_boot.img`, so a changed `prebuilts/dtb.img` otherwise ships stale. |
| a default `OUT_DIR` | A custom `OUT_DIR` breaks soong bootstrap for `test_package` modules. Move an old `out/` aside instead. |

This builds the release configuration: LineageOS sets `ro.adb.secure=1` and
`ro.debuggable=0`, so USB debugging needs the prompt on the phone and `adb root`
is unavailable. For bring-up work, `export WITH_ADB_INSECURE=true` before
building; adb then works without the prompt, also when the UI does not come up,
and the build stays debuggable. It is an `ifdef`, so `unset WITH_ADB_INSECURE`
to go back — setting it to `false` still enables it.

## Flashing

`flash.sh` next to the built images does the whole sequence. The essentials, if
you flash by hand:

- Unlock the bootloader first (Sony's official unlock; it wipes the device).
- Flash every partition with an explicit `_a` suffix and finish with
  `fastboot --set-active=a`. The bootloader under-reports `has-slot`, and a
  failed boot burns the slot retry counter until it falls over to the empty
  slot b and red-states with "device is corrupt".
- `fastboot flash super super.img` replaces the partitions that GApps live on.
  If you use GApps, reboot to recovery and sideload them again before booting.
- A `fastboot reboot` may print `usb_read failed`. The phone reboots anyway.

The "Flashing" section of PORTING-NOTES.md has the full sequence, including
recovery, the first boot after a data wipe, and what to do when a boot fails.

## Reporting problems

Include: the build you flashed, whether you used the same firmware dump version,
`adb shell getprop ro.lineage.version`, and a `logcat -b all` from the boot. For
kernel-side problems, `logcat -b kernel -d` carries the whole boot since the
kernel log buffer was raised to 1 MB.
