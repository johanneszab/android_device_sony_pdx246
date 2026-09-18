#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/sony/pdx246

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    odm \
    product \
    recovery \
    system \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_boot \
    vendor_dlkm

# Architecture
# Stock runs ro.zygote=zygote64_32, and ~100 vendor components (wfdservice,
# the CAS/OMX HALs, the soundtrigger impl, ssgqmigd) ship 32-bit only, so the
# second arch has to stay enabled.
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := kryo300

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := parrot
TARGET_NO_BOOTLOADER := true

# Display
TARGET_SCREEN_DENSITY := 450

# Kernel
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_BASE := 0x00000000
# To debug init, add printk.devkmsg=on loglevel=7 (see PORTING-NOTES.md, "log
# visibility"). log_buf_len raises the kernel ring from the 256K the stock dtb
# asks for: with the source kernel the ring wrapped before logd's first read,
# so the earliest ~106 kernel lines never reached logcat.
BOARD_KERNEL_CMDLINE := video=vfb:640x400,bpp=32,memsize=3072000 bootconfig log_buf_len=1M
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_KERNEL_IMAGE_NAME := Image

# The kernel is a GKI (android12-5.10) kernel, so declare it. Among other
# things this makes the build create the first_stage_ramdisk/ skeleton in the
# generic ramdisk, which the GKI first-stage init pivots into -- without it
# there is no first stage layout for the vendor ramdisk to land in. pdx257 sets
# this too.
BOARD_USES_GENERIC_KERNEL_IMAGE := true

# Stock and pdx257 both compress the ramdisks with LZ4; we were defaulting to
# gzip.
BOARD_RAMDISK_USE_LZ4 := true

# Stock ships these four in vendor_boot's bootconfig section and init depends
# on all of them. Without androidboot.hardware, ro.hardware is unset and init
# never loads init.qcom.rc, so the whole vendor init sequence is skipped;
# without androidboot.usbcontroller, init.recovery.qcom.rc cannot bring up the
# USB gadget and adb never appears in recovery.
BOARD_BOOTCONFIG += \
    androidboot.hardware=qcom \
    androidboot.memcg=1 \
    androidboot.usbcontroller=a600000.dwc3

# No androidboot.init_fatal_* options, as on pdx257: a fatal init error reboots
# to the bootloader. (Stock sets androidboot.init_fatal_panic=true.) For init
# debugging, androidboot.init_fatal_reboot_target=recovery keeps adb reachable.

# The kernel is built from source: LineageOS's Sony 5.10 kernel (sm8450) with
# pdx246's drivers and config from Sony's source release, and the vendor
# modules from Sony's module sources plus LineageOS's WLAN driver. See
# PORTING-NOTES.md, "Kernel from source".
TARGET_KERNEL_SOURCE := kernel/sony/sm6450
TARGET_KERNEL_CONFIG := \
    gki_defconfig \
    vendor/parrot_GKI.config \
    vendor/sony/columbia.config

# The device trees are built from source too, from kernel/sony/sm6450-devicetrees
# (Sony's copyleft device tree release), which the kernel picks up through
# arch/arm64/boot/dts/vendor. The build compiles the base DTBs and the board and
# techpack overlays, merge_dtbs.py folds the techpack overlays into the board
# ones, and the result becomes dtb.img (inside vendor_boot.img, with boot header
# v4) and dtbo.img. The wildcards keep the other SoCs in Sony's release out of
# the images; only parrot is enabled in the kernel config anyway.
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_USES_QCOM_MERGE_DTBS_SCRIPT := true
TARGET_NEEDS_DTBOIMAGE := true
TARGET_MERGE_DTBS_WILDCARD := parrot*
TARGET_MERGE_DTBOS_WILDCARD := parrot*

# Kernel modules, with stock's load lists and order (the default alphabetical
# order breaks drivers that must probe in sequence). The vendor_boot ramdisk
# loads modules.load in first stage: clk, pinctrl, regulator and smmu have to be
# up before the dynamic partitions can be mounted. Recovery also loads
# recovery.modules.load, and vendor_dlkm loads vendor_dlkm.modules.load. As on
# stock, the vendor_boot modules are in vendor_dlkm too.
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/vendor_dlkm.modules.load))
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(DEVICE_PATH)/vendor_dlkm.modules.blocklist
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load))
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load $(DEVICE_PATH)/recovery.modules.load))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_BLOCKLIST_FILE := $(DEVICE_PATH)/vendor_dlkm.modules.blocklist
BOOT_KERNEL_MODULES := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)

# Symbol providers come before their users (mmrm, rmnet core, rmnet shs).
TARGET_KERNEL_EXT_MODULE_ROOT := kernel/sony/sm6450-modules
TARGET_KERNEL_EXT_MODULES := \
    qcom/opensource/mmrm-driver \
    qcom/opensource/audio-kernel \
    qcom/opensource/camera-kernel \
    qcom/opensource/dataipa/drivers/platform/msm \
    qcom/opensource/datarmnet/core \
    qcom/opensource/datarmnet-ext/aps \
    qcom/opensource/datarmnet-ext/offload \
    qcom/opensource/datarmnet-ext/shs \
    qcom/opensource/datarmnet-ext/perf \
    qcom/opensource/datarmnet-ext/perf_tether \
    qcom/opensource/datarmnet-ext/sch \
    qcom/opensource/datarmnet-ext/wlan \
    qcom/opensource/display-drivers/msm \
    qcom/opensource/video-driver \
    qcom/opensource/wlan/qcacld-3.0/.adrastea \
    semc/hardware/charge/kernel-modules/battchg_ext \
    semc/ramdump/kernel-modules/last_logs \
    semc/ramdump/kernel-modules/rdtags

# Partitions
# The device has a real metadata partition (rootdir/etc/fstab.default mounts it
# and it is in the bootloader's partition table). This flag makes the build
# create the /metadata mount-point directory in the system image root; without
# it, SwitchRoot("/system") cannot MS_MOVE the already-mounted /metadata into
# the new root, and first-stage init aborts with
#   "Unable to move mount at '/metadata' to '/system/metadata'"
# which reboots the device to the bootloader before second-stage init starts.
BOARD_USES_METADATA_PARTITION := true

# Free space in system, system_ext and product for add-ons such as GApps, from
# LineageOS's BoardConfigReservedSize.mk as on pdx257. Device trees include it
# themselves; without it the ext4 images are built full and MindTheGapps aborts
# with "Not enough space for GApps!". false picks the larger product reserve
# (1957691392 bytes instead of 1188036608 for virtual A/B).
BOARD_PRODUCTIMAGE_MINIMAL_PARTITION_RESERVED_SIZE := false
-include vendor/lineage/config/BoardConfigReservedSize.mk

BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 25165824
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_SUPER_PARTITION_SIZE := 17179869184
BOARD_SUPER_PARTITION_GROUPS := somc_dynamic_partitions
BOARD_SOMC_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    vendor \
    vendor_dlkm \
    system_ext \
    odm \
    product
BOARD_SOMC_DYNAMIC_PARTITIONS_SIZE := 17175674880

# QTI/Sony vendor AIDs (2901-2999), taken from the stock vendor/etc/passwd.
# The vendor init scripts reference these groups by name, so host_init_verifier
# fails without them.
TARGET_FS_CONFIG_GEN := $(DEVICE_PATH)/config.fs

# Each of these is a real partition in the super image and is mounted
# separately per rootdir/etc/fstab.default, so stage them outside of /system
# instead of letting them default to system/<part>.
TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm

# Filesystem type per dynamic partition, matching rootdir/etc/fstab.default.
# Without these the images (and their NOTICE files) are never generated.
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4

# Platform
# NOTE: BOARD_USES_QCOM_HARDWARE is deliberately NOT set. It gates
# hardware/qcom-caf/common/BoardConfigQcom.mk (via BoardConfigLineage.mk), which
# would set QCOM_HARDWARE_VARIANT/QCOM_SOONG_NAMESPACE and make the
# hardware/qcom-caf/<variant> soong namespace visible. For parrot with
# TARGET_KERNEL_VERSION 5.10 that variant resolves to hardware/qcom-caf/sm8450,
# which is the Android 14/15-era CAF branch: it is HIDL-only (its allocator
# service is android.hardware.graphics.allocator@4.0, and it has no AIDL audio
# HAL at all), so it cannot supply any of the AIDL HALs Android 16 requires.
# Turning it on also makes 55 module names ambiguous between vendor/sony/pdx246
# (our blobs) and that namespace, every one of which would need pinning with
# //vendor/sony/pdx246:<name> just to preserve today's behaviour.
# Revisit only if we ever move the QTI HALs to source. See PORTING-NOTES.md.
TARGET_BOARD_PLATFORM := parrot

# Properties
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_SYSTEM_EXT_PROP += $(DEVICE_PATH)/system_ext.prop
TARGET_SYSTEM_DLKM_PROP += $(DEVICE_PATH)/system_dlkm.prop
TARGET_ODM_PROP += $(DEVICE_PATH)/odm.prop
TARGET_ODM_DLKM_PROP += $(DEVICE_PATH)/odm_dlkm.prop
TARGET_VENDOR_DLKM_PROP += $(DEVICE_PATH)/vendor_dlkm.prop

# Recovery
# Stock's recovery.img is ramdisk-only (kernel_size: 0) -- the kernel is taken
# from boot.img at boot time. Building a full boot-style recovery image with
# the 45MB GKI kernel embedded is a structure the bootloader will not accept,
# and it rejects the whole slot with the AVB red state ("device is corrupt").
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true

TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.default
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Security patch level
VENDOR_SECURITY_PATCH := 2026-07-01

# Verified Boot
#
# The rollback index must be >= the highest value the device has already
# recorded, or the bootloader rejects the image with "Your device is corrupt"
# (AVB red state) no matter what the disable flags say. Stock ships
# 1782864000 == 2026-07-01, so derive it from VENDOR_SECURITY_PATCH.
# PLATFORM_SECURITY_PATCH is 2025-11-05 here -- 238 days lower, which trips
# anti-rollback.
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_ALGORITHM := SHA256_RSA4096
BOARD_AVB_ROLLBACK_INDEX := $(shell date -u -d $(VENDOR_SECURITY_PATCH) +%s)

# rootdir/etc/fstab.default mounts system, system_ext and product with
# avb=vbmeta_system, so that chained vbmeta has to exist. It is also the only
# chain stock uses, at rollback index location 2 -- boot, dtbo, recovery and
# vendor_boot are plain hash descriptors in the main vbmeta. So deliberately
# do NOT set BOARD_AVB_{RECOVERY,VENDOR_BOOT}_KEY_PATH: that would turn them
# into chained partitions and claim index locations stock never used.
BOARD_AVB_VBMETA_SYSTEM := system system_ext product
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := $(BOARD_AVB_KEY_PATH)
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := $(BOARD_AVB_ALGORITHM)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(BOARD_AVB_ROLLBACK_INDEX)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2

# SEPolicy
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# QTI vendor policy. Without it none of the ~161 vendor services gets a domain
# ("has incorrect label or no domain transition from u:r:init:s0"), everything
# runs as init, and rmt_storage cannot serve the modem's NV requests -- the
# modem then starves and its watchdog panics the kernel:
#   qcom_q6v5_pas 4080000.remoteproc-mss: fatal error received:
#     dog_hb...: Task starvation: nv. ping: 4
#
# Use the upstream include rather than hand-picking dirs: the vendor policy,
# the QSSI public policy and the QSSI product policy are interdependent
# (attributes, hal types and property types are spread across all three), and
# every attempt to take a subset just surfaced the next missing declaration.
include device/qcom/sepolicy_vndr/SEPolicy.mk

# Sony's shared QTI policy, as on pdx257: types, labels and domains for Sony
# services such as the TA daemon, miscta, idd, secd, spc and the display HAL.
# Stock ships the equivalent in /odm/etc/selinux (odm_sepolicy.cil). Without
# it those services run in init's domain; see the SELinux label pre-check in
# PORTING-NOTES.md.
include hardware/sony/sepolicy/qti/SEPolicy.mk

# Statements about types that the two policies above declare. checkpolicy
# reads the policy directories in this order and needs a type declared before
# a typeattribute statement names it.
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor-after-sony

# VINTF
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/manifest.xml

# The vendor blobs serve a pile of QTI and Sony HALs that AOSP's framework
# matrix knows nothing about. The qcom-caf matrix covers the common QTI ones;
# the device matrix adds the Sony extensions and the rest.
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += \
    hardware/qcom-caf/common/vendor_framework_compatibility_matrix.xml \
    $(DEVICE_PATH)/framework_compatibility_matrix.xml

# Wi-Fi
# Builds hostapd for the hotspot (device.mk). BOARD_HOSTAPD_PRIVATE_LIB stays
# unset on purpose, so hostapd compiles its private driver commands out
# (external/wpa_supplicant_8/board_config_wpa_supplicant.mk). BOARD_WLAN_DEVICE
# stays unset too: hostapd's nl80211 driver defaults to the QCA variant.
BOARD_HOSTAPD_DRIVER := NL80211

# Inherit the proprietary files
include vendor/sony/pdx246/BoardConfigVendor.mk
