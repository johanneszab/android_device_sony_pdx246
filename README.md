# LineageOS 23.2 for the Sony Xperia 10 VI (pdx246)

An unofficial port, built and used daily on the author's device. The kernel,
the vendor modules and the device trees are built from source; the proprietary
parts come from a stock firmware dump that you supply yourself.

The engineering log of the port - why things are the way they are, what was
tried, what is still open - lives in a separate repository,
`android_device_sony_pdx246_notes`. It is a working log full of machine-specific
paths rather than documentation, so it is kept out of this repo; ask if you want
access.

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
   not been tested. A wrong dump usually shows up as a boot that stops before
   the UI, or as missing telephony.

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

Three points about that build invocation:

| | why |
|---|---|
| `lunch lineage_pdx246-...` in full | `breakfast pdx246` and `brunch pdx246` take the release from `vendor/lineage/vars/aosp_target_release` (currently `bp4a`) and silently build a different release configuration. |
| `-userdebug`, never `-eng` | `eng` disables dexpreopt, and the first boot then compiles the boot classpath on the device for over two hours. |
| a default `OUT_DIR` | A custom `OUT_DIR` breaks soong bootstrap for `test_package` modules. Move an old `out/` aside instead. |

This builds the release configuration: LineageOS sets `ro.adb.secure=1` and
`ro.debuggable=0`, so USB debugging needs the prompt on the phone and `adb root`
is unavailable. For bring-up work, `export WITH_ADB_INSECURE=true` before
building; adb then works without the prompt, also when the UI does not come up,
and the build stays debuggable. It is an `ifdef`, so `unset WITH_ADB_INSECURE`
to go back — setting it to `false` still enables it.

## Installing

The build produces two things you can install: a flashable zip
(`lineage-23.2-<date>-UNOFFICIAL-pdx246.zip`, an A/B payload) and the raw
partition images. Install the zip through LineageOS Recovery; that is the
path an end user takes, and the only one that exercises `update_engine`, so
it is also what later updates will use. The raw images are the development
path — see the next section.

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

   You find out only after sending the whole package, so skipping it costs
   a full transfer.

You never need to repeat this on the same phone. (The script is by the
LineageOS developers erfanoabdi and filipepferraz.)

### Installing the zip

From LineageOS Recovery, with the phone showing *Apply from ADB*:

```bash
adb -d sideload lineage-23.2-<date>-UNOFFICIAL-pdx246.zip
```

Watch the phone, not the terminal: `adb sideload` prints `Total xfer: 1.00x`
and exits 0 once the package has been *sent*, whether or not recovery then
installed it. A refused package looks exactly like a successful one on the
host. The screen shows the install progress and any `ERROR:` line, so treat
it as the result — this matters if you script the sequence.

Then *Reboot system now*. Coming from stock, factory reset first
(*Factory reset* → *Format data/factory reset*); the stock userdata is
encrypted with keys this build does not have.

If you use GApps, sideload them **before** the first boot — but recovery
will ask you to reboot *recovery* first, for the same reason as above, and
that is fine: rebooting recovery is not booting Android. What you must not do
is boot the system in between, because `update_engine` has just replaced the
partitions GApps live on, and booting once leaves GMS installed from
`/data` but unprivileged, with no privapp-permissions whitelist. It looks
like it works and then fails in odd ways.

## Flashing the built images directly

This is the development path: it writes the raw images over fastboot and skips
`update_engine` entirely. `flash.sh`, next to the built images, does the whole
sequence. The essentials, if you flash by hand:

- Unlock the bootloader first (Sony's official unlock; it wipes the device).
- Flash every partition with an explicit `_a` suffix and finish with
  `fastboot --set-active=a`. The bootloader under-reports `has-slot`, and a
  failed boot burns the slot retry counter until it falls over to the empty
  slot b and red-states with "device is corrupt".
- `fastboot flash super super.img` replaces the partitions that GApps live on.
  If you use GApps, reboot to recovery and sideload them again before booting.
- A `fastboot reboot` may print `usb_read failed`. The phone reboots anyway.

`flash.sh` covers recovery, the first boot after a data wipe and the retry
behaviour this device needs; read it before flashing by hand.

Because this path only ever writes slot a, it does not keep the two slots in
step — do the copy-partitions step above as well.

## Reporting problems

Include: the build you flashed, whether you used the same firmware dump version,
`adb shell getprop ro.lineage.version`, and a `logcat -b all` from the boot. For
kernel-side problems, `logcat -b kernel -d` carries the whole boot since the
kernel log buffer was raised to 1 MB.
