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

# android.hardware.boot: NOT CURRENTLY PROVIDED.
# The matrix only accepts AIDL, so the HIDL @1.2 service is useless here, but
# QTI's AIDL replacement does not build against our prebuilt kernel headers:
#   libgptutils.qti: bionic/libc/include/sched.h:99: redefinition of
#   'sched_param' (previous definition in the generated kernel headers'
#   linux/sched/types.h)
# It is only needed by update_engine for A/B slot management, not to boot, so
# it is left out. REVISIT before OTAs are expected to work.

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

# Mount points
# rootdir/etc/fstab.default mounts modem/dsp/bluetooth firmware and vm-system
# under /vendor. The mount-point directories have to exist in the vendor image
# or the mounts silently fail -- which is why adsprpcd loops on
# "apps_dev_init failed ... No such device" (no DSP firmware) and the firmware
# -dependent HALs abort. Same class of bug as the missing /metadata dir.
PRODUCT_PACKAGES += \
    vendor_bt_firmware_mountpoint \
    vendor_dsp_mountpoint \
    vendor_firmware_mnt_mountpoint \
    vendor_vm-system_mountpoint

# Hardware feature declarations
#
# pdx246 shipped ZERO of these: `find $OUT -path '*etc/permissions/android.hardware.*'`
# returned nothing, while stock declares 41 and device/sony/pdx257 copies 52.
# The framework therefore believed this device had no wifi, bluetooth, nfc,
# camera, sensors, telephony, fingerprint, usb or vulkan.
#
# That is not cosmetic. DisplayManagerService.registerWifiDisplayAdapterLocked()
# throws outright when config_enableWifiDisplay is set (it is, because we ship
# WfdService) and android.hardware.wifi.direct is absent:
#   FATAL EXCEPTION IN SYSTEM PROCESS: android.display
#   java.lang.RuntimeException: WiFi display was requested, but there is no
#     WiFi Direct feature   (WifiDisplayAdapter.java:110)
# which killed system_server at ~997 s.
#
# The list is stock's own declarations, which is the authority on what this
# hardware actually has. Two of stock's 41 are deliberately excluded:
#   - android.hardware.light.xml declares a shared LIBRARY, not a feature, and
#     points at /system/framework/android.hardware.light-V2.0-java.jar, which
#     is not present even in the stock dump.
#   - android.hardware.hardware_keystore.xml has no AOSP source and a
#     device-specific version, so it lives in permissions/ here instead.
#
# Deliberately NOT copied, though stock has them:
#   android.software.freeform_window_management.xml -- pdx257 does not ship it
#     either and it is unrelated to bring-up; revisit if freeform is wanted.
#   android.software.{opengles,vulkan}.deqp.level.xml -- generated per device by
#     the build with a dEQP level value, not static files in AOSP.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.low_latency.xml \
    frameworks/native/data/etc/android.hardware.audio.pro.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.pro.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.camera.concurrent.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.concurrent.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.full.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.full.xml \
    frameworks/native/data/etc/android.hardware.camera.raw.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.raw.xml \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    frameworks/native/data/etc/android.hardware.keystore.app_attest_key.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.keystore.app_attest_key.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.nfc.ese.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.ese.xml \
    frameworks/native/data/etc/android.hardware.nfc.hce.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.hce.xml \
    frameworks/native/data/etc/android.hardware.nfc.hcef.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.hcef.xml \
    frameworks/native/data/etc/android.hardware.nfc.uicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.uicc.xml \
    frameworks/native/data/etc/android.hardware.nfc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.se.omapi.ese.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.se.omapi.ese.xml \
    frameworks/native/data/etc/android.hardware.se.omapi.uicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.se.omapi.uicc.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepcounter.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepdetector.xml \
    frameworks/native/data/etc/android.hardware.telephony.euicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.euicc.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.ims.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.vulkan.compute-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.compute-0.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level-1.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version-1_1.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.passpoint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.passpoint.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.software.device_id_attestation.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.device_id_attestation.xml \
    frameworks/native/data/etc/android.software.ipsec_tunnels.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.ipsec_tunnels.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    frameworks/native/data/etc/android.software.verified_boot.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.verified_boot.xml

# Audio
# BRING-UP PLACEHOLDER: audioserver on Android 16 requires the AIDL audio HAL
# (android.hardware.audio.core.IModule). Sony's stock HAL is HIDL
# (android.hardware.audio.service_64), which is the wrong generation and
# SIGABRTs on startup, so system_server hangs in AudioService.<init>. This
# AOSP reference implementation registers the AIDL interfaces so the boot can
# proceed. There is NO working audio with it -- the real fix is the QTI AIDL
# HAL (audiohalservice.qti plus the PAL/AGM stack), as pdx257 does.
PRODUCT_PACKAGES += \
    com.android.hardware.audio

# The reference effect HAL reads /vendor/etc/audio_effects_config.xml. AOSP's
# copy is a prebuilt_etc gated behind a soong config bool that is off by
# default, so copy the file directly rather than flipping that gate.
PRODUCT_COPY_FILES += \
    hardware/interfaces/audio/aidl/default/audio_effects_config.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects_config.xml

# Sensors
# The multihal binary was shipped as a blob but its init .rc was not, so no
# service ever declared android.hardware.sensors@2.1::ISensors and
# system_server blocked forever in SystemSensorManager.nativeCreate(). AOSP's
# module provides the binary, the .rc and the VINTF fragment together, and
# soong already claims those install paths, so build it rather than extract it.
PRODUCT_PACKAGES += \
    android.hardware.sensors-service.multihal

# vndbinder
# The QTI vendor blobs (rild, the telephony and camera HALs) talk over
# /dev/binderfs/vndbinder, which needs vndservicemanager to be running. Without
# it those services get ENOENT on the vndbinder lookups seen in the boot log.
PRODUCT_PACKAGES += \
    vndservicemanager

# USB
# The QTI gadget HAL reads /vendor/etc/usb_compositions.conf to map a
# composition name (e.g. "adb") onto configfs functions and a VID/PID. Without
# it the gadget is never bound and the device does not enumerate over USB at
# all in Android. vendor/qcom/opensource/usb/hal defines the module; it just
# was never in PRODUCT_PACKAGES. Shipping the stock blob instead collides with
# that module's install rule, so build it from source as pdx257 does.
# Android 16 dropped HIDL usb.gadget: compatibility_matrix.7 lists it as
# format="hidl" version 1.0-2, matrix 8 onwards only has format="aidl". The
# stock @1.2-service-qti blob is HIDL, so hwservicemanager refuses it --
#   getTransport: Cannot find entry android.hardware.usb.gadget@1.2::IUsbGadget
#   Cannot register USB Gadget HAL service
# and adb never enumerates. Build QTI's AIDL services instead (they ship their
# own .rc and VINTF fragments), as pdx257 does.
PRODUCT_PACKAGES += \
    android.hardware.usb-service.qti \
    android.hardware.usb.gadget-service.qti \
    usb_compositions.conf

# Thermal
# The stock android.hardware.thermal@2.0-service.sony blob is HIDL; the matrix
# only accepts AIDL. Build QTI's AIDL thermal service instead.
PRODUCT_PACKAGES += \
    android.hardware.thermal-service.qti

# Vibrator
# vendor/qcom/opensource/vibrator/aidl builds both the impl and the
# service; the stock blob service is not usable against the source impl.
PRODUCT_PACKAGES += \
    vendor.qti.hardware.vibrator.service

# Health
PRODUCT_PACKAGES += \
    android.hardware.health-service.qti

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
    fstab.default.vendor_ramdisk \
    init.qcom.factory.rc \
    init.qcom.rc \
    init.qcom.usb.rc \
    init.qti.kernel.rc \
    init.qti.ufs.rc \
    init.target.rc \
    init.recovery.qcom.rc \

# Soong namespaces
# hardware/qcom-caf/{bootctrl,thermal} each declare their own soong_namespace,
# so the AIDL boot and thermal services are invisible without opting in.
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    hardware/qcom-caf/bootctrl \
    hardware/qcom-caf/thermal

# Inherit the proprietary files
$(call inherit-product, vendor/sony/pdx246/pdx246-vendor.mk)
