#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Add common definitions for Qualcomm
$(call inherit-product, hardware/qcom-caf/common/common.mk)

# Enable updating of APEXes
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# A/B
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_vendor=true \
    POSTINSTALL_PATH_vendor=bin/checkpoint_gc \
    FILESYSTEM_TYPE_vendor=ext4 \
    POSTINSTALL_OPTIONAL_vendor=true

PRODUCT_PACKAGES += \
    checkpoint_gc \
    otapreopt_script

PRODUCT_PACKAGES += \
    android.hardware.boot@1.2-impl \
    android.hardware.boot@1.2-impl.recovery \
    android.hardware.boot@1.2-service

PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier

# AAPT
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxhdpi

# API levels
PRODUCT_SHIPPING_API_LEVEL := 34

# Boot animation
TARGET_SCREEN_HEIGHT := 2520
TARGET_SCREEN_WIDTH := 1080

# fastbootd
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

# Power
# The stock blob implements AIDL power V1, which no framework
# compatibility matrix accepts. Build the QTI HAL, which is V6.
PRODUCT_PACKAGES += \
    android.hardware.power-service-qti

# Vibrator
# vendor/qcom/opensource/vibrator/aidl builds both the impl and the
# service; the stock blob service is not usable against the source impl.
PRODUCT_PACKAGES += \
    vendor.qti.hardware.vibrator.service

# Health
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-service

# Kernel
PRODUCT_ENABLE_UFFD_GC := true

# The kernel uses 4K pages (stock reports ro.product.cpu.pagesize.max=4096).
# This has to come from the product variable; setting the property directly in
# product.prop collides with the one the build generates.
PRODUCT_MAX_PAGE_SIZE_SUPPORTED := 4096

# NFC
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/nfc/libnfc-nxp-typef.conf:$(TARGET_COPY_OUT_VENDOR)/etc/libnfc-nxp-typef.conf

# Overlays
PRODUCT_ENFORCE_RRO_TARGETS := *

PRODUCT_PACKAGES += \
    SonyPDX246SystemUIRes \
    SonyPDX246NfcNciRes \
    SonyPDX246FrameworksRes

DEVICE_PACKAGE_OVERLAYS += \
    $(LOCAL_PATH)/overlay-lineage

# Partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Product characteristics
PRODUCT_CHARACTERISTICS := default

# Rootdir
PRODUCT_PACKAGES += \
    AudioPlayback.sh \
    init.class_main.sh \
    init.crda.sh \
    init.kernel.post_boot-parrot.sh \
    init.kernel.post_boot-ravelin.sh \
    init.kernel.post_boot.sh \
    init.mdm.sh \
    init.qcom.class_core.sh \
    init.qcom.coex.sh \
    init.qcom.early_boot.sh \
    init.qcom.efs.sync.sh \
    init.qcom.post_boot.sh \
    init.qcom.sdio.sh \
    init.qcom.sensors.sh \
    init.qcom.sh \
    init.qcom.usb.sh \
    init.qti.display_boot.sh \
    init.qti.kernel.debug-parrot.sh \
    init.qti.kernel.debug-ravelin.sh \
    init.qti.kernel.debug.sh \
    init.qti.kernel.early_debug-parrot.sh \
    init.qti.kernel.early_debug.sh \
    init.qti.kernel.sh \
    init.qti.media.sh \
    init.qti.qcv.sh \
    init.qti.touch_boot.sh \
    init.qti.write.sh \
    qca6234-service.sh \
    vendor_modprobe.sh \

PRODUCT_PACKAGES += \
    fstab.default \
    init.qcom.factory.rc \
    init.qcom.rc \
    init.qcom.usb.rc \
    init.qti.kernel.rc \
    init.qti.ufs.rc \
    init.target.rc \
    init.recovery.qcom.rc \

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.default:$(TARGET_VENDOR_RAMDISK_OUT)/first_stage_ramdisk/fstab.default

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# Inherit the proprietary files
$(call inherit-product, vendor/sony/pdx246/pdx246-vendor.mk)
