#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/sony/pdx246

# Sony's ramdump tooling in kernel/sony/pdx246-modules ships a soong plugin.
# Soong rejects plugins it does not already know about, and that repo is
# repo-synced, so allow-list it here instead of patching it there.
BUILD_BROKEN_PLUGIN_VALIDATION += soong-somc_platform_flag_default

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
# printk.devkmsg=on lifts the rate limit on userspace /dev/kmsg writes; without
# it init's messages are dropped after the module-load flood and its errors
# never reach ramoops.
# loglevel=7 because the bootloader passes loglevel=6, which prints only
# levels 0-5 and therefore filters out init's LOG(INFO) -- including every
# "starting service" line, which makes it impossible to tell whether a service
# ran at all. ignore_loglevel would also work but prints every kernel debug
# message and wraps the 256K ramoops console buffer well before the
# interesting part of the boot. DEBUG ONLY.
BOARD_KERNEL_CMDLINE := video=vfb:640x400,bpp=32,memsize=3072000 bootconfig printk.devkmsg=on loglevel=7
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_KERNEL_IMAGE_NAME := Image

# This device boots a stock GKI kernel, so declare it. Among other things this
# makes the build create the first_stage_ramdisk/ skeleton in the generic
# ramdisk, which the GKI first-stage init pivots into -- without it there is no
# first stage layout for the vendor ramdisk to land in. pdx257 sets this too.
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

# ---- DEBUG BUILD ONLY: revert both of these before any daily use ----
# selinux=permissive because there is no device sepolicy yet and the stock
# Sony blobs will generate denials. Stock also sets
# androidboot.init_fatal_panic=true, which is deliberately omitted here so an
# init failure logs and continues rather than panicking the kernel instantly,
# which left us with nothing to read.
BOARD_BOOTCONFIG += \
    androidboot.selinux=permissive \
    androidboot.init_fatal_reboot_target=recovery
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_KERNEL_SEPARATED_DTBO := true
TARGET_KERNEL_CONFIG := pdx246_defconfig
TARGET_KERNEL_SOURCE := kernel/sony/pdx246

# Kernel - prebuilt
TARGET_FORCE_PREBUILT_KERNEL := true
ifeq ($(TARGET_FORCE_PREBUILT_KERNEL),true)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilts/kernel
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilts/dtb.img
BOARD_MKBOOTIMG_ARGS += --dtb $(TARGET_PREBUILT_DTB)
BOARD_INCLUDE_DTB_IN_BOOTIMG := 
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilts/dtbo.img
BOARD_KERNEL_SEPARATED_DTBO := 
endif

# Kernel modules
# The device boots a stock GKI image, so the 265 vendor modules come from the
# stock vendor_dlkm rather than being built from source. modules.load.order
# preserves stock's load sequence -- the default (alphabetical) order breaks
# drivers that must be probed in a particular sequence. depmod regenerates
# modules.dep/alias/softdep at build time, so those are not carried over.
BOARD_VENDOR_KERNEL_MODULES := \
    $(wildcard $(DEVICE_PATH)/prebuilts/modules/*.ko)
BOARD_VENDOR_KERNEL_MODULES_LOAD := \
    $(addprefix $(DEVICE_PATH)/prebuilts/modules/,\
        $(shell cat $(DEVICE_PATH)/prebuilts/modules/modules.load.order))
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := \
    $(DEVICE_PATH)/prebuilts/modules/modules.blocklist

# First-stage modules live in the vendor_boot ramdisk, not vendor_dlkm: clk,
# pinctrl, regulator and smmu have to be up before the dynamic partitions can
# even be mounted. 210 of these are byte-identical to the vendor_dlkm copies;
# stock ships both sets, so mirror that rather than trying to share one copy.
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := \
    $(wildcard $(DEVICE_PATH)/prebuilts/modules-vendor_boot/*.ko)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := \
    $(addprefix $(DEVICE_PATH)/prebuilts/modules-vendor_boot/,\
        $(shell cat $(DEVICE_PATH)/prebuilts/modules-vendor_boot/modules.load.order))
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := \
    $(addprefix $(DEVICE_PATH)/prebuilts/modules-vendor_boot/,\
        $(shell cat $(DEVICE_PATH)/prebuilts/modules-vendor_boot/modules.load.recovery.order))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_BLOCKLIST_FILE := \
    $(DEVICE_PATH)/prebuilts/modules-vendor_boot/modules.blocklist

# Partitions
# The device has a real metadata partition (rootdir/etc/fstab.default mounts it
# and it is in the bootloader's partition table). This flag makes the build
# create the /metadata mount-point directory in the system image root; without
# it, SwitchRoot("/system") cannot MS_MOVE the already-mounted /metadata into
# the new root, and first-stage init aborts with
#   "Unable to move mount at '/metadata' to '/system/metadata'"
# which reboots the device to the bootloader before second-stage init starts.
BOARD_USES_METADATA_PARTITION := true

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

# Audio
# hardware/interfaces/audio/aidl/default ships audio_effects_config.xml behind
# this soong config; it is off by default, so PRODUCT_PACKAGES cannot reference
# the module without it. android.hardware.audio.effect.service-aidl.example
# (EffectMain.cpp kDefaultConfigName) looks for exactly that filename, and our
# blobs only carry the legacy HIDL audio_effects.xml. Enabling it pairs AOSP's
# effects config with the AOSP effect libs bundled in com.android.hardware.audio.
$(call soong_config_set_bool,hardware_interfaces_audio,use_default_audio_effects_config,true)

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

# BRING-UP ONLY -- REVERT BOTH.
# The qva/ policy contains `allow dumpstate vold:binder call`, which violates an
# AOSP neverallow. That rule needs fixing properly; this bypasses the check.
SELINUX_IGNORE_NEVERALLOWS := true

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
