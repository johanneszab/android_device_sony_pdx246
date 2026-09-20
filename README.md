# LineageOS 23.2 for the Sony Xperia 10 VI (pdx246)

An unofficial port, as close to the official LinageOS charter as possible. The kernel,
the vendor modules and the device trees are built from source; the proprietary
parts come from a stock firmware dump that you supply yourself.

__Note:__ This port is to large parts vide-coded. See the commits. I created the initial
device tree, but Opus 5 fixed most of the blob / version issues. I'll likely only
irregular create new updates, if at all. Keep that in mind in case of you're going to
install one of the releases. However, as the releases are not signed, everyone with the
code can create a new update and install it over the existing installation.

## State of the port

Working: boot to the UI, display and touch, Wi-Fi (including the 5 GHz
hotspot), Bluetooth, NFC with the secure element, mobile data, calls, VoLTE and
Wi-Fi calling, GPS, audio including the speaker, headset and in-call paths, all
five cameras with photo and video, hardware video decoding, the fingerprint
sensor, sensors, the vibrator, charging with LineageOS charging control,
LiveDisplay, and suspend on battery (98% asleep with the screen off). SELinux
is enforcing.

## Supported variants

| Model | Market | Tested |
|---|---|---|
| `XQ-ES54` | EEA (Europe) | yes, this is the author's device |
| `XQ-ES72` | Hong Kong, Taiwan, Singapore, Malaysia, Thailand, Vietnam, Macau | no, see below |

One build serves both, because the two are the same device with a different
sticker. Comparing Sony's `70.2.A.4.168` firmware for each, byte for byte:
`vendor` (3437 files), `system_ext` (1830), `vendor_dlkm` (274), `odm` (47) and
`system` (2981) are **identical**, and of the 3208 blobs this port extracts,
3207 are identical. The single exception is the NFC RF tuning table, and the
phone picks the right one by itself at runtime: the NFC HAL reads
`/sys/devices/platform/HardwareInfo/modem_id` and loads
`/vendor/etc/libnfc-nxp_RF_C2.conf` on an `XQ-ES72` instead of
`/vendor/libnfc-nxp_RF.conf`. Both files ship.

What an `XQ-ES72` does **not** get right, because the build carries one
identity for everyone and it is the author's:

- *Settings > About phone* reports the model as `XQ-ES54`.
- Sony's carrier configuration is keyed on the model, so nine settings meant
  for the `XQ-ES72` are missed: VoNR stays enabled where stock disables it on
  Hong Kong (454-12/13/30), Malaysia (502-12), Thailand (520-01/03) and
  Singapore (525-03/05), and 5G NR availability is not cleared on Vietnam
  (452). Everything else about mobile data and calls is shared.

## What you need

1. **A LineageOS 23.2 tree.** About 220 GB for `.repo` plus the checkout, and
   another ~210 GB for `out/`, so plan for roughly 450 GB free. A full build
   takes about three hours on a 20-core machine.
2. **This device tree and the three kernel repos**, via the local manifest
   below. They are all the port needs on top of the LineageOS default
   manifest, plus `hardware/sony`, which the default manifest does not carry.
3. **A stock firmware dump** for this exact device, extracted (for example with
   [dumpyara](https://github.com/AndroidDumps/dumpyara)), with `vendor/`,
   `system/`, `product/` and `odm/` at its top level. Blobs are not
   redistributable, so they are not part of any of these repos. The current
   state was built from `XQ-ES54_EEA-user 16 70.2.A.4.168`
   (`070002A004016801749288677`). The matching `XQ-ES72` firmware works just as
   well as a source: every blob this port takes is identical between the two
   except the NFC RF table, which is selected at runtime anyway. A different
   firmware *version* may work but has not been tested. A wrong dump usually
   shows up as a boot that stops before the UI, or as missing telephony.

The kernel repos are separate because the kernel is built from source:

| Path | Repo | Branch |
|---|---|---|
| `device/sony/pdx246` | `android_device_sony_pdx246` | `lineage-23.2` |
| `kernel/sony/sm6450` | `android_kernel_sony_sm6450` | `pdx246` |
| `kernel/sony/sm6450-modules` | `android_kernel_sony_sm6450-modules` | `lineage-23.2` |
| `kernel/sony/sm6450-devicetrees` | `android_kernel_sony_sm6450-devicetrees` | `lineage-23.2` |

The kernel is a fork of LineageOS's `android_kernel_sony_sm8450` (its
`lineage-23.2` branch is that upstream unchanged; `pdx246` adds this device's
drivers and config). The modules repo holds Sony's vendor module sources plus
LineageOS's WLAN driver. The devicetrees repo is Sony's copyleft device tree
release; the kernel picks it up through `arch/arm64/boot/dts/vendor`, so it has
to sit next to the kernel under that exact name. SM6450 is this device's SoC —
do not confuse it with the sm8450 devices (Xperia 1 IV, 5 IV).

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
           remote="johanneszab" revision="lineage-23.2" />
  <project path="kernel/sony/sm6450" name="android_kernel_sony_sm6450"
           remote="johanneszab" revision="pdx246" />
  <project path="kernel/sony/sm6450-modules" name="android_kernel_sony_sm6450-modules"
           remote="johanneszab" revision="lineage-23.2" />
  <project path="kernel/sony/sm6450-devicetrees" name="android_kernel_sony_sm6450-devicetrees"
           remote="johanneszab" revision="lineage-23.2" />

  <project path="hardware/sony" name="LineageOS/android_hardware_sony"
           remote="github" />
</manifest>
```

`lineage.dependencies` in this repo only names `hardware/sony`, because
roomservice can only fetch repos owned by the LineageOS organisation. The four
repos above therefore have to come from the local manifest.

The kernel repo carries the full upstream history and is about 3.8 GB. Add
`clone-depth="1"` to that project if you do not need the history; the build
does not.

## Setup and build

```bash
./device/sony/pdx246/setup.sh /path/to/stock/dump
source build/envsetup.sh
lunch lineage_pdx246-trunk_staging-userdebug
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

## Installing

The build produces two things you can install: a flashable zip
(`lineage-23.2-<date>-UNOFFICIAL-pdx246.zip`, an A/B payload) and the raw
partition images.

### Once per device, before the first install

The Xperia 10 VI has two slots, and LineageOS only ever writes one of them.
Whatever firmware the other slot holds stays there: on a phone that has been
updated a few times, that can be much older than the active slot, and booting
into it can range from "no modem" to a hard brick. Sony's own official
LineageOS devices (pdx203, pdx206, pdx214, pdx215, pdx223, pdx224, pdx225,
pdx234, pdx235, pdx237, pdx245, pdx257 — all of them) carry this same step,
and it exists because this is not a hypothetical.

Copy the active slot's firmware onto the inactive one, once:

1. Unlock the bootloader (Sony's official unlock — it wipes the device).
2. Boot LineageOS Recovery.
3. Download
   [`copy-partitions-20220613-signed.zip`](https://mirrorbits.lineageos.org/tools/copy-partitions-20220613-signed.zip).
4. On the phone choose *Apply update* → *Apply from ADB*, then on the host:

   ```bash
   adb -d sideload copy-partitions-20220613-signed.zip
   ```

5. *Advanced* → *Reboot to recovery*. **Not optional**, and it is the step
   that is easy to skip: copying the partitions leaves the logical
   partitions mapped, and `update_engine` refuses to install an OTA in that
   state with

   ```
   ERROR: recovery: Logical partitions are mapped. Please reboot recovery
   before installing an OTA update
   ```

### Installing the zip

From LineageOS Recovery, with the phone showing *Apply from ADB*:

```bash
adb -d sideload lineage-23.2-<date>-UNOFFICIAL-pdx246.zip
```

Then *Reboot system now*. Coming from stock, factory reset first
(*Factory reset* → *Format data/factory reset*); the stock userdata is
encrypted with keys this build does not have.

If you use GApps, sideload them **before** the first boot
