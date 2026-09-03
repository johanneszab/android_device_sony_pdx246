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
    system \
    vendor \
    vendor_dlkm \
    system_ext \
    odm \
    product
BOARD_USES_RECOVERY_AS_BOOT := true

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
BOARD_KERNEL_CMDLINE := video=vfb:640x400,bpp=32,memsize=3072000 bootconfig
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_KERNEL_IMAGE_NAME := Image
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
BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 25165824
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_SUPER_PARTITION_SIZE := 9126805504 # TODO: Fix hardcoded value
BOARD_SUPER_PARTITION_GROUPS := sony_dynamic_partitions
BOARD_SONY_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    vendor \
    vendor_dlkm \
    system_ext \
    odm \
    product
BOARD_SONY_DYNAMIC_PARTITIONS_SIZE := 9122611200 # TODO: Fix hardcoded value

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
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.default
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Security patch level
VENDOR_SECURITY_PATCH := 2026-07-01

# Verified Boot
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1
BOARD_AVB_VENDOR_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VENDOR_BOOT_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX := 1
BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX_LOCATION := 1

# VINTF
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/manifest.xml

# The vendor blobs serve a pile of QTI and Sony HALs that AOSP's framework
# matrix knows nothing about. The qcom-caf matrix covers the common QTI ones;
# the device matrix adds the Sony extensions and the rest.
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += \
    hardware/qcom-caf/common/vendor_framework_compatibility_matrix.xml \
    $(DEVICE_PATH)/framework_compatibility_matrix.xml

# Inherit the proprietary files
include vendor/sony/pdx246/BoardConfigVendor.mk
